Standalone Aurora Relayer and Refiner
=

## Prerequisites and Dependencies
* x86-64 architecture
* requires [Curl]
* requires [Docker], recommended versions;
  * Docker Engine v20.10.18 and above
* optional [AWS Account], if near datalake on AWS S3 to be used
* optional Near Account, for [Write Transactions & Custom Signers]
* depends on [Aurora Relayer2], Web3-compatible relayer server for Aurora
* depends on [Aurora Refiner], allows users to download all NEAR Blocks and get all information relevant to Aurora

## How to Install and Start
```shell
git clone https://github.com/aurora-is-near/standalone-rpc
cd standalone-rpc
git checkout {version tag}
./install.sh
```

Installer configures standalone-rpc, downloads required Near and Aurora snapshots and starts containers to serve RPC 
and sync with blockchain. Depending on your network bandwidth and CPU downloading of snapshots and syncing with the 
chain may take some time. All installation artifacts and chain data are placed under `standalone-rpc/srpc2` directory.

Upon installation, the RPC endpoint is served at http://127.0.0.1:20080/ as well as on the public IPs of your computer.

By default, standalone-rpc installer is configured to work on `mainnet` and near blocks to be consumed from `nearcore`. See installer usage for more details.

```shell
Usage: install.sh [options]
Options
 -n {mainnet|testnet}	network to use, default is mainnet.
 -r {nearcore|datalake}	near source for indexing, default is nearcore.
 -w {number [1-256]}	number of workers used for downloading near snapshots, default is 256.
			NOTE: On some OS and HW configurations, default number of workers may cause high CPU consumption during download.
 -s			if specified then snapshots are ignored during installation, default downloads and uses snapshots.
			NOTE: Ignoring snapshots may cause refiner not to index near chain. This can only be a valid option
			if near source is selected as datalake otherwise refiner will not be sync with near core from scratch.
 -h			prints usage
			
Examples
 ./install.sh -n mainnet -r datalake -s
 AWS_SHARED_CREDENTIALS_FILE=~/.aws/credentials ./install.sh -r datalake -s
```

## How to Stop & Start
After installation completes, standalone-rpc should start to serve RPC and catch up with the network. You can always 
**stop** and **start** standalone-rpc by executing the `./stop.sh` or `./start.sh` scripts placed under `srpc2` directory.

## How to Update Containers
The services/containers in this installation is updated automatically. Whenever Aurora releases a new image, it will be downloaded, and services are restarted. In case you would like to use a
specific version instead of the latest version, please check out [How to use specific version]

This is however not true for the included database and chain files. These are only downloaded initially when running `./install.sh`. Keep your node running to prevent going out of sync.

## How to Use Specific Version
Users who are willing to use a specific Relayer and/or Refiner version other than the latest version, should follow the below steps after installation;
* change directory to installation location
* change the docker image version of the service (relayer/refiner) in `docker-compose.yaml` file under `srpc2`

  e.g.: if you prefer to use relayer v2.0.0 instead of v2.1.0 (assuming this is the latest), `docker-compose.yaml` file should look like
  ```yaml
  ...
  relayer:
    image: nearaurora/srpc2-relayer:v2.0.0
  ...
  ```
* restart services to have the change take effect
  ```shell
  ./stop.sh && ./start.sh
  ```
  
**IMPORTANT**: Please note that, for the services you prefer to work with specific version other than latest, you will not receive any hot-fix or feature updates.

## How to collect Support Information
Users who are encountering problems and looking for a support for their installations, are encouraged to share some support information which helps us to identify problems. 
To collect support information, installations with version `v2.1.1` (see, [From v2.1.0 to v2.1.1] for older versions) and above provides a script called `support.sh` under `srpc2` directory. User can run this script which collects following information;
* OS version
* Docker, Docker-Compose version
* Memory, Disk, CPU Info
* relayer and refiner versions, logs, and container info

Upon running the script a tar ball with the following name `support-log-<timestamp>.tar.gz` is created under `srpc2` directory. 

## How to Uninstall
```shell
cd standalone-rpc
./uninstall.sh
```

**IMPORTANT** this operation does the followings
* stops and removes Aurora standalone-rpc related docker containers, volumes and networks
* deletes configuration
* asks user for deletion of data, default does not delete


## Write Transactions & Custom Signers
The default installation does not support write transactions. It just sets up a placeholder account and a file for 
further customizations. To enable write transactions with your account, you need to follow the steps below:
* Create an account on testnet/mainnet and load some NEAR on it.
* Export the account's keypair and name into `srpc2/config/relayer/relayer.json` (check the original file for format).
* Change the `signer` value in the `srpc2/config/relayer/relayer.yaml` to the account's name.
* Restart standalone-rpc.

## Good to Know 
* [Aurora Relayer2] configuration can be changed from `srpc2/config/relayer/relayer.yaml`. Some configuration changes can be applied without requiring a restart, please see repository page for more details about configuration.
* standalone-rpc uses [Nginx] as a reverse-proxy before [Aurora Relayer2] RPC endpoints. To change [Nginx] configuration, edit the config file `srpc2/config/nginx/endpoint.conf`, and restart standalone-rpc

## Migration and Update of Installation
### from v2.0.2 to v2.1.0
For those who already have a running Aurora Standalone RPC with version `v2.0.2`, the existing Near Data can be reused. 
Meaning that, installer can skip the time-consuming Near Snapshot download step and use the Near Data of existing installation.
Follow the below steps, if you prefer the reuse existing Near Data.
* change directory to previous installation
* checkout version 2.1.0
* run installer with migration option and pass the current directory as parameter
#### Notes
 * You can also use existing data by cloning repo from scratch to another directory. In that case, instead of current 
directory, you have to pass the path to `v2.0.2` installation directory with `-m` option  
 * When it is run with migration option, installer does stop the previous installation before starting new one, but it 
does not do any cleanup on previous installation data or configuration, it is users responsibility to keep or delete them
 * Never delete the following directories of the previous installation, after migration they are linked and reused by the 
new version
   * `<previous standalone-rpc path>/near`
   * `<previous standalone-rpc path>/engine`
#### Example
```shell
cd ~/repo/standalone-rpc/
git fetch
git checkout v2.1.0
./install.sh -m .
```

### from v2.1.0 to v2.1.1
* change directory to previous installation
* checkout version 2.1.1
* copy `contrib/bin/support.sh` to `srpc2/support.sh`

[Curl]: https://curl.se/
[Nginx]: https://www.nginx.com/
[Docker]: https://docs.docker.com/engine/install/
[Docker-Compose]: https://docs.docker.com/compose/install/
[AWS Account]: https://youtu.be/GsF7I93K-EQ?t=277
[Aurora Relayer2]: https://github.com/aurora-is-near/relayer2-public
[Aurora Refiner]: https://github.com/aurora-is-near/borealis-engine-lib
[Write Transactions & Custom Signers]: https://github.com/aurora-is-near/standalone-rpc#write-transactions--custom-signers
[From v2.1.0 to v2.1.1]: https://github.com/aurora-is-near/relayer2-public#from-v2.1.0-to-v2.1.1
[How to use specific version]: https://github.com/aurora-is-near/relayer2-public#how-to-use-specific-version
