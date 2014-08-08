# linkup

A JavaScript library providing dead simple file sharing via WebRTC DataChannels. It allows to connect to a listening peer and send native JavaScript [`File`](https://developer.mozilla.org/en-US/docs/Web/API/File) objects.

*linkup* uses [PeerJS](https://github.com/peers/peerjs) to handle the WEBRTC connections and serialization.

## Documentation

coming soon!

## Getting Started

Alice and Bob want to share files.

This is Alice:

```coffee
alice = new linkup.Peer()    # create a new Peer object

alice.id    # => 'gd38v7'
# Alice then sends her peer ID to Bob...

# ...and waits for incoming connections.
alice.on 'open', () ->
	# Alice is now connected to Bob
	console.log "connected to #{alice.peer}"
alice.listen()    # listen for connections
```

This is Bob:

```coffee
bob = new linkup.Peer()    # create a new Peer
bob.connect 'gd38v7'    # connect to Alice using her peer id

bob.on 'open', () ->
	# Bob is now connected to Alice
	console.log "connected to #{bob.peer}"

bob.send bobsFile    # send the File to alice
```

All files Alice and Bob receive will be downloaded and saved automatically. The connection between Alice and Bob works in both directions.