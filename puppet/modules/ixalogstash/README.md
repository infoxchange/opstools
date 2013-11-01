I'm going to assume you're using puppet 3, we're using puppet 3.3.1

I have tested this on puppet 2.6 and it works, but you need to fix a couple of things in the modules to make it compatible with 2.6 (It might work with 2.7)

1.  Clone these to your `/etc/puppet/modules`:
     * https://github.com/bloonix/logstash-delete-index
     * https://github.com/puppetlabs/puppetlabs-rabbitmq (optional)
     * https://github.com/logstash/puppet-logstash
     * https://github.com/puppetlabs/puppetlabs-vcsrepo

2.  Setup your elasticsearch cluster

    Have a look at our uber-simple elasticsearch cluster setup in `modules/ixaelastic/init.pp`

3.  Create a Kibana git repo on your git server for deployment with ixalogstash

    You can see in `ixalogstash.pp` I've cloned the kibana code into a local git repo, and I'm deploying it with the official puppetlabs vcsrepo git provider

4.  Webserver for Kibana hosting

    We use nginx to host it at Infoxchange, we have a class called ixanginx which will create an nginx vhost from a directory

    You'll need to change this to whatever module you use to host websites (i.e. puppetlabs apache module etc...)

5.  Apply ixalogstash class to your node and pass the parameters in

6.  Profit!
