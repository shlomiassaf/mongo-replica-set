# MongoDB Replica Set for test

A MongoDB Replica Set  running in a single docker container.

---

### Not For Production
The key motivation for this image is to have a __ready-made__ replica set of MongoDB running inside docker container for __CI tests__.

---

This repo is based on [CandisIO/mongo-replica-set](https://github.com/CandisIO/mongo-replica-set).

Adding the following enhenchments:

- Initial startup wait for all nodes to initialize before configuring the replica set.
- Logs from all nodes print to **stdout**
- **$PUBLIC_HOST** environment variable to expose the hostname instead of ipaddress


### Docker CLI

To run the container, execute the following command:

```bash
docker run -d -p 27017:27017 -p 27018:27018 -p 27019:27019 shlomiassaf/mongo-replica-set
```

Once ready, the replica-set can be accessed using the following connection string:

```bash
mongodb://localhost:27017,localhost:27018,localhost:27019/?replicaSet=rs0 #... your additional config
```

Note that **localhost** (or **127.0.0.1**) is accessible from the host machine and will not work inside other containers.

For example, running unit tests on you maching (the host) against the replica-set container at 127.0.0.1


#### Access the ReplicaSet from other containers

To access the replica-set from other containers we need to use the IP Address of the replica-set container or an alias (hostname) the resolve to that ip address.

Docker provide this (assuming we're using a brige network) for us, we just need to define the **--hostname**:

```bash
docker run --hostname mongodb -d -p 27017:27017 -p 27018:27018 -p 27019:27019 shlomiassaf/mongo-replica-set
```

And inside service container use the following connection string:

```bash
mongodb://mongodb:27017,mongodb:27018,mongodb:27019/?replicaSet=rs0 #... your additional config
```

This will be able to connect to the replica set but will fail when trying to connect to each replica set node.

The reason is that the replica set configuration, by default, is using **127.0.0.1** as the default replica-set node address:

```js
rs.initiate({
    _id : 'rs0',
    members: [
        { _id : 0, host : "127.0.0.1:27017" },
        { _id : 1, host : "127.0.0.1:27018" },
        { _id : 2, host : "127.0.0.1:27019" } 
    ]
});
```

So when the client in a container try to connect it will first resolve connectoin string, successfully connect to the replica-set (via **mongdb** hostname) just to get an updated replica-set server list resolving to **127.0.0.1** for each server thus failing to connect.

To solve this, we can use the **$PUBLIC_HOST** environment variable which will ensure the replica set is configured properly:

```bash
docker run --env PUBLIC_HOST=mongodb --hostname mongodb -d -p 27017:27017 -p 27018:27018 -p 27019:27019 shlomiassaf/mongo-replica-set
```

And now the replica set is configured propertly:

```js
rs.initiate({
    _id : 'rs0',
    members: [
        { _id : 0, host : "mongodb:27017" },
        { _id : 1, host : "mongodb:27018" },
        { _id : 2, host : "mongodb:27019" } 
    ]
});
```

Note that with this setup you will not be able to reach the replica-set servers from the host on OSX.

```bash
mongodb://localhost:27017,localhost:27018,localhost:27019/?replicaSet=rs0 #... your additional config
```

The above will get you to the replica-set but, as seen above, the replica-set will update the servers so each node is accessible using the hostname **mongodb** which is unreachable from the docker host machine.

To solve this issue you need to add dns mapping to the file `/etc/hosts`

```bash
127.0.0.1       mongodb
```

To avoid adding multiple hosts to your machine, syncing it with the team, you can use
a single host **host.docker.internal** which is also what you put in **PUBLIC_HOST** and now
accessing the replica set is working from host and containers.

## Docker Compose

```yaml
version: "3.9"
services:
  web:
    build: .
    ports:
        - "8000:80"
    depends_on:
        - db
    depends_on:
      - mongodb
  mongodb:
    profiles:
      - mongo
    image : shlomiassaf/mongo-replica-set:5.0.10
    hostname: mongodb
    volumes:
      - "/docker-mount/mongodb/mongo1:/var/lib/mongo1"
      - "/docker-mount/mongodb/mongo2:/var/lib/mongo2"
      - "/docker-mount/mongodb/mongo3:/var/lib/mongo3"
    environment:
      - PUBLIC_HOST=mongodb
    ports:
      - 27017:27017
      - 27018:27018
      - 27019:27019
```