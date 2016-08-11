```
    ____________   ______            __    
   / ____/ ____/  /_  __/___  ____  / /____
  / /_  /___ \     / / / __ \/ __ \/ / ___/
 / __/ ____/ /    / / / /_/ / /_/ / (__  ) 
/_/   /_____/    /_/  \____/\____/_/____/  
```

*Automation and Configuration Orchestration for F5 Load Balancers*

## Installation 

Clone the repo and then run:
```
$ gem build f5_tools.gemspec
$ gem install f5_tools-x.x.x.gem
```

Use F5Tools in your own ruby projects with:

```ruby
gem 'f5_tools'
```

## Getting Started
### Tool Concepts
#### Facilities and Devices
F5_Tools defines a few concepts to describe how F5 load balancers are used in a production environment. A `facility` is a full instantiation of a server setup. Facilities can - and often do - have multiple F5 balancers within them. A `device` is a single instance of one of these balancers. As devices often perform analogous duties across different facilities, they can be templatized. Devices are given hostnames, so that F5_Tools can connect to the F5 REST API an each device. Facilities have an internal CIDR block attribute, which is used to describe their internal network address space.

![Facility Image](img/FacilityDevice.png)

#### Segments, Endpoints, Port Symbols
A *segment* is a method of describing a subnet within a facility. Segments are named, and can either be defined with a CIDR sized, or specified manually. Size-defined segments are allocated automatically using the internal CIDR block of the facility.

*Endpoints* are named addresses, and are used to describe destination addresses for various `ltm` objects like VIPs and Snatpools.

*Port Symbols* are named ports, and are used to describe service ports.

### Coming from an existing setup
These steps will allow you to begin setting up a F5_Tools configuration based on the settings that already exist on your F5.

Suppose we have a facility in Boston named `bos`, and a load balancer named `front`. Run the following commands to setup a representation of the facility and device (load balancer) you're currently working with.

  ```
  f5tools define facility bos
  f5tools define device front
  ```

When you define a `facility`, `f5tools` will ask you for an internal CIDR block and an external endpoint. This is not necessary to have correctly configured for the purposes of this tutorial. When you define the device, make sure that the hostname resolves to the current device.

Run `f5tools diff device front`. This will print out a comprehensive list of all the objects that exist on the server. You can begin to add these to your local definitions using the `create` and `define` commands. 

### Configuring a Basic Facility
```
# Setup a facility
f5tools define facility bos

# Add a device
f5tools define device front

# Create some app nodes
f5tools create node host my-app-host-01.company.com name APP_01 -f bos
f5tools create node host my-app-host-02.company.com name APP_02 -f bos
f5tools create node host my-app-host-03.company.com name APP_03 -f bos

# Add those nodes to a pool
f5tools create pool name POOL_APP members APP_01,APP_02,APP_03 -d front

# Apply these changes to your F5 device
f5tools apply device bos front
```

### Tooling Workflow

The intended workflow of F5Tools for maintenance / adjustment tasks is as follows:

1. Use the tools creation / definition commands to edit the local config (or directly edit the YAML files in `defs/`)
* Run `f5tools diff` on the device that you've made local adjustments to. This is to confirm the intent of the user, and to ensure that no production critical 'mistakes' will be made by applying the local definitions to the load balancer.
* Run `f5tools apply` on the devive you've adjusted to *overwrite* the server's config with the local config.

When starting out, it is reccomended that you use the `f5tools create`, `f5tools define`, and `f5tools delete` to adjust the local settings of F5Tools. These commands give useful creation wizards to help users who are inexperienced with the tool effectively modify the load balancer's config.

However, advanced users will be better served by managing and editing the YAML defs manually. These YAML files can be found in the `defs/` directory. Additionally, there is a sample set of YAML files in the `dist/defs/` directory that provide explanation of the various YAML schemas used by the tool.

## Usage

```
Commands:
  f5tools apply [SUBCOMMAND]     # Applies local configuration to the server
  f5tools create <object_type>   # Creates an F5 Object (Node, Pool, Vip, etc.)
  f5tools define [SUBCOMMAND]    # Define F5_Tools constructs (Facilities, Devices, etc.) in local configuration
  f5tools delete [SUBCOMMAND]    # Delete F5 Objects from local configuration
  f5tools diff [SUBCOMMAND]      # Diff local configuration against server config
  f5tools generate [SUBCOMMAND]  # Generation commands for vlans, json, device templates
  f5tools help [COMMAND]         # Describe available commands or one specific command
  f5tools list [SUBCOMMAND]      # Lists F5 Objects from local configuration
```

### Authentication
* Username, password, and host can be passed as CLI arguments (see above)
  * Hostname should normally be specified in the appropriate `net_device` YAML
* Username and password can be set as ENV variables (`F5_USERNAME` and `F5_PASSWORD` respectively)
* If not passed as argument or env variable, the tool will challenge you for credentials at runtime

### Example Usage
Scenario: Items have changed in the config for `ord/front`.

1. Run `f5tools diff device ord front` to get a complete sense of what has changed.
2. You can run `f5tools apply device ord front` to push the local config to the F5.
3. Suppose you only wanted to change `vip` configs. Then, it would be appropriate to run `f5tools apply ord front -t vip`
3. Suppose you only wanted to make a change to the `pool` named `PROD_APP`. Then, run `f5tools apply ord front -t pool -n PROD_APP`.

### Notes for Users
#### Apply

`apply` has the following behavior: It **creates** objects that exist in local config, but not in the server. It **modifies** objects that exist in the server, but have differing properties in the local config. It **does not delete** objects that exist in the server, but not in the local config.

#### Diff
`diff` pulls down the server configuration from the F5 and compares it to objects defined in your local configuration (it is **read only**)


#### Misc.

* All `Datagroup`s and `iRules` in their respective folders are uploaded to the server when applied. (They are 'global' entities)
* Creating `client-ssl` profiles can sometimes fail because the certs must be uploaded to the F5 first. (F5 requires that the named `.crt` exist in the server before allowing a profile to be created)
  * Use `f5tools upload_cert_tgz` to quickly upload a `.tgz` of certs/keys and register all of those certs/keys with the F5.
* Use `mkpasswd -m sha-512 <password>` to create the hashed password for user account management

### Advanced Users

* Device templates (in `defs/device_templates/`) can be formatted using [Liquid](https://shopify.github.io/liquid/) or [ERB](https://en.wikipedia.org/wiki/ERuby). Device templates are rendered in the context of a Facility, so any variables stored in the facility's `_vars.yaml` can be used as template variables in the device yaml.
* Templating can also be aided by the smart use of endpoints and node names. For example, analogous nodes can be labeled `SERVICE_NODE_01`, `SERVICE_NODE_02`, etc in the template, and then be given full FQDNs in each facility's `nodes.yaml`. This can be done similarly with endpoints.

![Templating](img/TemplateStructure.png)

## Config
### File Tree
The `defs/` file tree should look something like this (taken from `dist/defs/`).
```
defs
├── data_groups
│   └── sample_data_group.yaml
├── facilities
│   └── sample_facility
│       ├── endpoints.yaml
│       ├── net_devices
│       │   └── sample_net_device.yaml
│       ├── nodes.yaml
│       └── segments.yaml
├── facilities.yaml
├── irules
│   └── RULE_sample
├── monitors.yaml
├── port_symbols.yaml
├── profiles.yaml
├── segments.yaml
└── whitelist.yaml
```
### Setting up a Facility
1. Run `f5tools create facility <facility_name>` to create a new facility folder / YAML set.
2. Alter `<YOUR_FACILITY>/segments.yaml` and `<YOUR_FACILITY>/endpoints.yaml`, etc. appropriately (see example YAMLs in `dist/` for details).
3. Run `f5tools create net_device <device_name>` for each net device in the facility. This creates a YAML in `<YOUR_FACILITY>/net_devices/`
7. If necessary, upload client-ssl keys/certs with the `upload_cert_tgz` command.
8. The facility is now configured. It can now be used in commands like `diff`, `apply`, etc along with it's net_devices.

## F5 Object Tree
* `Facility` - Complete server configuration (e.g. `iad`, `ord`)
    * `NetDevice` - Single F5 pair (e.g. `front`, `border`)
        * `Vip` - Layer 7 LTM Virtual
        * `Forwarder` - Layer 4 LTM Virtual
          * `XSiteForwarder` - Abstract forwarder that generates forwarder rules between facilities
        * `Node` - Host endpoint
        * `Pool`
        * `Snatpool`
        * `Monitor` - Only supports HTTP type right now (same as `f5_mgmt`)
        * `Datagroup` - Typed map used by iRules
        * `Profile` - Currently supports: http, client-ssl, and fastl4 profiles
        * `IPSec`
          * `IKEPeer`
          * `IPSecPolicy`
          * `TrafficSelector`
        * `DHCPRelay` - Manages DHCP Relay abstraction: An LTM Virtual pointing to a `DHCP_RELAY` pool with the DHCP node as its only member.
        * `VLAN`
        * `ESNAT` - LTM Virtual, similar to a `Forwarder`, but with an attached `Snatpool`
    * `Segment` - Named CIDR Block (`CORP`, `APP`, etc)
    * `PortSymbol` - Named Port (`SSH`, `HTTP`, `DNS`, etc) [Actually managed by `Resolution` module]

Included, but unimplemented objects:
* `ManagementRoute`
* `PacketFilter`
* `SnatTranslation`

*Note:* Some objects, like `Profile`s, are managed by the `NetDevice`, but are defined globally. This is because there is nothing `NetDevice`-specific about the `Profile`, but it makes sense that the `NetDevice` has responsibility for managing profiles that it contains.

![Object Distribution](img/ObjectDistribution.png)

## Implementation Notes
### F5_Object
There are two types of F5_Object: abstract (`facility`, `net_device` etc.), and concrete (`node`, `pool`, etc.). Concrete objects exist in some form on the F5, and thus _must_ respond to `#diff` and `#apply`. Abstract objects may respond to `#diff` and `#apply`, but only to call those methods on child objects that they manage.

* `#diff` - Does something and returns a `true` iff there is a difference between the YAML defs and what's configured on the server. Also should print out some helpful log info describing the diff. `F5_Object` does not have a default `#diff` method (as each object diffs itself differently), but there are some useful helper functions like `#get_server_config` and the `Assertion` module
* `#apply` - Overwrites the current config with those in the YAML defs. There are some objects (of note, `node`) that cannot be modified (enforced by F5). `F5_Object` does have a default `#apply` method that is acceptable for most use cases. The default is to use the return value of `#to_json` as the payload.
  * In the case that `#apply` is modifying an object - not creating it - the default `#apply` will use the return of `#modify_safe_json` as the payload.
* `@path` and `@ext` - `@path` is a Ruby Class Instance Variable of an F5_Object that defines the 'base directory' of that object class on the F5. `@ext` is an 'Instance Instance' Variable that specifies the unique location of that instance of the F5_Object on the F5. So, `<BASE_URL> + @path + @ext` should be the full URL of the object

### YAMLUtils Specific Nodes
* To allow integrations with commands like `f5tools create object`, F5_Objects should have `YAML_LOC`, `CREATION_INFO`, and possibly `YAML_KEY` defined. See existing F5_Objects for implementation examples.

### F5Wrapper

Loosely wraps the iControl REST API. Provides `#authentication` method, and `get`/`put`/`post` lines to the F5 once authenticated.

### Miscellany
* `pool` member name that want to target 'any' port should have the extension `:0` instead of `:any` (F5's naming scheme)
* Cannot change `type` of `data_group` via modify - unlikely to be a problem
* The enforced upper limit for a internal data group (`DataGroup`) is 15kb - any larger and perf becomes an issue.
* Abstract F5_Objects may have their `@name` be an array (to support global name diffing). In these cases, the first element in the array is the 'abstract' name and will not be used in the global name check, but can still be used as the selector for a class+name based diff.

## Documentation

1. Run `rake yard` to generate the docs.
2. Run `yard server` to start docs server on `localhost:8808` (by default)
