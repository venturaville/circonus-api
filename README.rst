Circonus API
===================

Provide a ruby class to interface with the Circonus API

Note: You need to define an API token first

Also provides a ruby class to interface with the Data API used by Javascript in their UI.

Note: For the Data API you should use a readonly username and password

Docs
-------------

# API documentation is here
  https://login.circonus.com/resources/api

# API Tokens can be created here:
  https://circonus.com/user/tokens

# Beacons:
  https://circonus.com/docs/beacons/circonus_beacon_instructions.pdf

# Broker user manual:
  https://circonus.com/account/tbs/broker_user_manual

# RPMs for broker:
  http://updates.circonus.com/circonus/x86_64/RPMS/

Circonus API
-------------

Generally speaking, Circonus tables are layed out like this:

checks -> check_bundles -> graphs -> worksheets -> dashboards

rules -> rulesets

contacts -> contact_groups

brokers

templates

Circonus Data
-----------------

The data is returned JSON encoded.  Composites are not totaled, but are represented.  You can use them to figure out what needs to be totaled.

Prerequisites
---------------

You will minimally need a working circonus API authentication token, in order to use this gem.

::

  # Set API token (required or it needs to be passed on command line)
  export CIRCONUS_APITOKEN="9999999-9999-9999-99999999"

  # Set app name (optional, default: curl)
  export CIRCONUS_APPNAME="curl"

  # If you are using Circonus inside, or have a different API endpoint:
  export CIRCONUS_APISERVER="circonusinsidehostname"

API
-------------

Most functions are available using any of:

  - list_(name)({OPTIONAL_HASH_OF_MATCHING_KEY_AND_VALUES}) # hash is used for filtering
  - get_(name)(id)
  - add_(name)(data)
  - update_(name)(id,data)
  - delete_(name)(id)
  - search_(name)(regex_string,field_name) # this is done using list for now (avoid if possible)... 

The list of names (for default v2 API) are:

  - account
  - annotation
  - broker
  - check_bundle
  - contact_group
  - graph
  - rule_set
  - template
  - user
  - worksheet
  - alert (only valid for get and list)
  - data (only valid for get)

API Examples
-------------

::

    require 'circonus'

    @apitoken="blahblahblah"
    @appname="curl"

    hosts = ARGV

    c = Circonus.new(@apitoken,@appname)

    agents = c.list_broker
    #pp agents


::

    graphs = list_graph()

::

    # Use the graph id from a specific graph to get info on it
    get_graph('/graph/aeda0a3a-aaea-e7a4-b5ad-9a7ab11bc44b')

CLI Examples
-------------

Everything in the API should be available in the CLI directly


::

    >> get_graph('f35228a3-cf46-e034-dcf8-f7470a5aaaaf')['title']
    => "Site Graph test"

::

    # get list of methods available
    >> help

::

    # Find US based brokers:
    >> search_broker('US$','_name').map { |b| b['_name'] }
    => ["San Jose, CA, US", "Ashburn, VA, US"]

::

    # Find users with firstname Joe:
    >> list_user({'firstname'=>'Joe'})
    => [{"_cid"=>"/user/1195", "email"=>"joe.smith@wherever.com", "firstname"=>"Joe", "lastname"=>"Smith"}]


::

    # Get data from a time range
    # - check bundle ID
    # - metric name
    # - (options: start, end (Time)  period (int seconds)  type (numeric, text, etc..)
    >> get_data('53061','tt_firstbyte',{'start'=>(Time.now - 300).to_i})
    url=https://api.circonus.com/v2/data/53061_tt_firstbyte
    => {"_cid"=>"/data/59030_tt_firstbyte", "data"=>[[1376055900, {"count"=>5, "counter"=>0.911668002605438, "counter_stddev"=>1.54755294322968, "derivative"=>0.726139008998871, "derivative_stddev"=>1.4332150220871, "stddev"=>86.7077865600586, "value"=>208.4}]]}

::

    # Get graph, fetch data, and evaluate all datapoint and composite formulas 
    >> gd = get_graph_data('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',(Time.new - 86400).to_i)


Utilities
----------------


::

    # Add a simple composite check using tags
    $ CIRCONUS_APITOKEN=99999999-9999-9999-9999-999999999999
    $ circonus-add-composite --name 'aggregation`cpu-average`cpu`idle'  --metric counter --stats mean --filter mytagname:mytagvalue,scope:prod --tags mytagname:mytagvalue,scope:prod

