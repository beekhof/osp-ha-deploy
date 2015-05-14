#!/usr/bin/python -tt

import argparse
import collections
import inspect
import logging
import sys

try:
    from novaclient import client as nova_client
except ImportError:
    logging.error("nova not found or not accessible")
    sys.exit(1)


# NOTE(sbauza): Necessary as the contrib path is not imported directly
try:
    from novaclient import extension
    from novaclient.v2.contrib import migrations
except ImportError:
    logging.warning("migrations can't be done since the module is not there")
    migrations = None


def register_named(cls):
    cls.methods_map = {}
    cls.methods_pos_map = {}
    cls.methods_opt_map = {}
    for methodname in dir(cls):
        method = getattr(cls, methodname)
        if hasattr(method, '_named'):
            cls.methods_map.update({method._named: methodname})
            if hasattr(method, '_pos'):
                cls.methods_pos_map.update({method._named: method._pos})
            if hasattr(method, '_opts'):
                cls.methods_opt_map.update({method._named: method._opts})
    return cls


def named(method_name, positionals=[], opts_with_val=[], opts_without_val=[]):
    """Decorator for providing the shell name for the method and the optional
    arguments.

        :method_name: Shell name for the method (like "service-enable")
        :positionals: List of strings corresponding to a positional
        :opts_with_val: Optionals that accept a value (like --foo bar)
        :opts_without_val: Optionals that are boolean (like --foo)
    """
    def wrapped(func):
        func._named = method_name
        func._pos = positionals
        func._opts = dict(map(lambda x: (x, True), opts_with_val) + map(
            lambda x: (x, False), opts_without_val))
        return func
    return wrapped


def shell_fields(fields):
    """Decorator for providing the list of fields to show up in CLI."""
    def wrapped(func):
        func.fields = fields
        return func
    return wrapped


@register_named
class NovaClientWrapper(object):
    """Wrapper for accessing a subset of novaclient API."""

    def __init__(self, version, username, password, tenant_name, auth_url):
        if migrations:
            extensions = [extension.Extension('migrations', migrations)]
        else:
            extensions = None
        self.nova = nova_client.Client(version, username, password,
                                       tenant_name, auth_url,
                                       extensions=extensions)

    @shell_fields(["Id", "Binary", "Host", "Zone", "Status", "State",
                   "Updated_at"])
    @named('service-list', opts_with_val=['host', 'binary'])
    def service_list(self, host=None, binary=None):
        services = self.nova.services.list(host=host, binary=binary)
        return services

    @shell_fields(['Host', 'Binary', 'Status'])
    @named('service-enable', positionals=['host', 'binary'])
    def service_enable(self, host, binary):
        return self.nova.services.enable(host=host, binary=binary)

    @shell_fields(['Source Node', 'Dest Node', 'Source Compute',
                   'Dest Compute', 'Dest Host', 'Status', 'Instance UUID',
                   'Old Flavor', 'New Flavor', 'Created At', 'Updated At'])
    @named('migration-list', opts_with_val=['host', 'status', 'cell_name'])
    def migration_list(self, host=None, status=None, cell_name=None):
        if hasattr(self.nova, 'migrations'):
            return self.nova.migrations.list(host=host, status=status,
                                             cell_name=cell_name)

    # NOTE(sbauza); We mimic the host-servers-migrate module
    def _server_migrate(self, server):
        success = True
        error_message = ""
        try:
            self.nova.servers.migrate(server=server['uuid'])
        except Exception as e:
            success = False
            error_message = "Error while migrating instance: %s" % e
        response = collections.namedtuple(
            'HostServersMigrateResponse',
            ['server_uuid', 'migration_accepted', 'error_message'])
        response._make([server['uuid'], success, error_message])
        return response

    @shell_fields(["Server UUID", "Migration Accepted", "Error Message"])
    @named('host-servers-migrate', positionals=['host'])
    def host_servers_migrate(self, host):
        hypervisors = self.nova.hypervisors.search(host, servers=True)
        response = []
        for hyper in hypervisors:
            if hasattr(hyper, 'servers'):
                for server in hyper.servers:
                    response.append(self._server_migrate(server))
        return response

    def handle_method_and_args(self, args_list):
        (method, extra) = (None, None)
        kwargs = {}
        for meth in self.methods_map:
            try:
                pos = args_list.index(meth)
            except ValueError:
                # Method not found
                continue
            method_name = args_list[pos]
            method = getattr(self, self.methods_map[method_name])
            extra = args_list[:pos] if pos > 0 else None
            args = args_list[pos+1:]
            spec = inspect.getargspec(method)
            for arg in args:
                opt = arg.rsplit("-")[-1]
                if opt in spec.args:
                    if opt in self.methods_opt_map[method_name]:
                        if self.methods_opt_map[method_name][opt] is True:
                            # This is an opt followed by its value
                            try:
                                val = args[args.index(arg)+1]
                            except IndexError:
                                # The opt was awaiting a value, invalidating it
                                args.remove(arg)
                                continue
                            kwargs[opt] = val
                            args.remove(arg)
                            args.remove(val)
                        else:
                            # This is an opt True or False
                            kwargs[opt] = True
                            args.remove(arg)
            # Let's zip the remainings arguments with the awaiting positionals
            positionals = dict(zip(self.methods_pos_map[method_name], args))
            kwargs.update(positionals)
            break
        return (extra, method, kwargs)


def print_list(objs, fields):
    # find max column width
    columnWidth = 0
    for obj in objs:
        for field in fields:
            field_name = field.lower().replace(' ', '_')
            width = len(str(getattr(obj, field_name, '')))
            if width > columnWidth:
                columnWidth = width
            if len(field) > columnWidth:
                columnWidth = len(field)

    outputStr = '+' + ('-'*(columnWidth + 2) + '+')*len(objs) + '\n'
    outputStr += '| ' + " | ".join([field.ljust(columnWidth)
                                   for field in fields]) + " |\n"
    outputStr += '+' + ('-'*(columnWidth + 2) + '+')*len(objs) + '\n'
    for obj in objs:
        rowList = []
        for field in fields:
            field_name = field.lower().replace(' ', '_')
            rowList.append(str(getattr(obj, field_name, '')
                               ).ljust(columnWidth))
        outputStr += '| ' + ' | '.join(rowList) + " |\n"
    outputStr += '+' + ('-'*(columnWidth + 2) + '+')*len(objs) + '\n'
    return outputStr


def main():
    logging.getLogger().addHandler(logging.StreamHandler(stream=sys.stderr))

    parser = argparse.ArgumentParser()
    parser.add_argument("--os-auth-url", required=True, dest='auth_url')
    parser.add_argument("--os-username", required=True, dest='username')
    parser.add_argument("--os-password", required=True, dest='password')
    parser.add_argument("--os-tenant-name", required=True, dest='tenant_name')
    parser.add_argument("remainder", nargs=argparse.REMAINDER,
                        help="nova command followed by its args")

    args = parser.parse_args()
    method_and_args = args.remainder
    nova = NovaClientWrapper('2', args.username, args.password,
                             args.tenant_name, args.auth_url)
    (extra, method, kwargs) = nova.handle_method_and_args(method_and_args)
    if method is None:
        logging.error("Method not mapped in %s", method_and_args)
        return 1
    result = method(**kwargs)
    print_list([result] if not isinstance(result, list) else result,
               method.fields)

if __name__ == "__main__":
        sys.exit(main())
