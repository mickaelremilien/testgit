# Image Factory

Prerequisites:

* Openstack Heat Client
* Operating system based on Debian

Steps:

* Heat Orchestration Template with a valid Nova key pair
* SSH tunnel to access Jenkins interface
* Add Git plugin and other major plugins to deployed Jenkins
* Verify existence of OpenStack credentials in your .profile
* Restart Jenkins
* Inject your private key to bind the session
* The sky is the limit!

TODO:

* Cleanup volumes
* Dynamically attain floating IP address for deployed images
* Run tests on newly deployed images using floating IP
