# linkup
# A JavaScript library providing dead simple file sharing via WebRTC DataChannels.
# Jannis R <jannisr.de>
# v0.1.0





# dependencies
uid = require './uid.coffee'
EventEmitter = require './EventEmitter.coffee'
File = require './File.coffee'





# A `Peer` is one of the two participants of a linkup connection. A `Peer` is responsible for sending and receiving all files in its queue.
class Peer extends EventEmitter




	# each peer has a unique id by which it can be found in the pool of peers
	id: null
	# the id of the connected peer
	peer: null

	# Since `linkup` is based on PeerJS, `_peerjs` is a reference to a `PeerJS.Peer` object. This object is responsible for signaling, connecting and sending messages and data.
	_peerjs: null

	# The PeerJS data connection used to transfer commands.
	_commandConnection: null
	# The PeerJS data connection used to transfer (file) data.
	_dataConnection: null

	# The peer listening for other peers connecting will be the controller once they are connected. The controller decides which files will be transferred next. By that, two files never get transferred at the same time.
	isController: null
	# `isOpen` is `true`, if the peers currently are connected successfully.
	isOpen: null
	# `isIdle` is `true`, if currently all files have been transferred.
	isIdle: null

	# A List of `linkup.File` objects the peer will send or receive. Both peers synchronize this list. Already transferred files will not be removed.
	files: null
	# The `linkup.File` currently being transferred.
	currentFile: null




	constructor: () ->
		super    # call super class constructor

		@id = uid 6

		# controller, connected, open, idle
		@on 'open', () ->
			@isOpen = true
			@isIdle = false
		@on 'close', () ->
			@isOpen = false
			@isIdle = false
		@on 'error', () ->
			@isOpen = false
			@isIdle = false
		@on 'complete', () ->
			@isIdle = true
		@on 'transfer', () ->
			@isIdle = false

		# _peerjs
		@_peerjs = new window.Peer @id,
			key: '2c5evmxvq0i442t9'    # PeerJS cloud API key
		# todo: move to self-hosted PeerJS server
		@_peerjs.on 'close', () =>
			@_log 'underlying PeerJS peer closed'
			@emit 'close'
		@_peerjs.on 'error', (error) =>
			@_log "underlying PeerJS peer throw an error: #{error}", 'error'
			@emit 'error', error
		# @connect(id) adds an event handler for `open`.
		# @listen() adds an event handler for `connection`.

		# file queue
		@files = []

		# events
		@on 'open', @_onOpen
		@on 'open', () ->
			@_log 'connection open'
		@on 'close', @_onClose
		@on 'close', () ->
			@_log 'connection closed'
		@on 'error', @_onClose
		@on 'error', () ->
			@_log 'connection closed due to an error'
		@on 'add', (file) ->
			@_log "file added: #{file.name}"

		# business logic
		@on 'add', @_checkSendCommand
		@on 'progress', @_checkSendCommand
		@on 'open', @_checkSendCommand

		# initial status
		@emit 'close'




	# Connect to a peer by giving an id.
	connect: (id) ->
		@_log "connecting to peer #{id}"

		@isController = false

		# callback, called once PeerJS ready
		onOpen = () =>
			# setup messaging connection
			@_commandConnection = @_peerjs.connect @peer,
				label: 'messages'
				serialization: 'none'
				reliable: true
			@_onConnection @_commandConnection

			# setup data connection
			@_dataConnection = @_peerjs.connect @peer,
				label: 'data'
				serialization: 'binary'
				reliable: true
			@_onConnection @_dataConnection

		@peer = id
		return onOpen() if @_peerjs.open    # connection already established, call callback directly
		@_peerjs.on 'open', onOpen


	# Listen for connections by other peers.
	listen: () ->
		@_log 'listening for connections'

		@isController = true    # This peer will be the controller.

		# callback, called once a peer connects
		onConnection = (connection) =>
			connections =    # list of all connections required
				'messages': '_commandConnection'
				'data': '_dataConnection'

			# check if the connections has a valid label
			if not connection in connections
				return @_log "request with invalid label `#{connection.label}`", 'warn'

			# check if already connected
			if this[connections[connection.label]] and this[connections[connection.label]].open
				connection.close()    # reject request
				return @_log "#{connection.label} connection already established", 'warn'

			# store peer id and connection
			@peer = connection.peer
			this[connections[connection.label]] = connection
			@_onConnection connection

		# wait for a connection
		@_peerjs.on 'connection', onConnection


	# Handle a PeerJS peer connection that has been established.
	_onConnection: (connection) ->
		# callback, called once a connection is open
		onOpen = () =>
			# check connections
			return if not @_commandConnection or not @_commandConnection.open
			return if not @_dataConnection or not @_dataConnection.open

			# bind business logic
			@_commandConnection.on 'data', @_onCommand
			@_dataConnection.on 'data', @_onData

			@emit 'open'

		# callback, called once a connection closes or throws an error
		onCloseOrError = () =>
			@emit 'close'
			# todo: Reconnect on connection loss.
			# todo: Detach event handlers from the PeerJS connections.

		if connection.open
			onOpen()
		connection.on 'open', onOpen
		connection.on 'close', onCloseOrError
		connection.on 'error', onCloseOrError




	# Add a `linkup.File` to the list of files.
	add: (file) ->
		return if file in @files    # abort if file has already been added

		# add file to list of files
		@files.push file
		@files[file.id] = file

		# broadcast file to peer
		if file.mode is 'send' and @isOpen
			@_sendCommand 'metadata', file,
				name: file.name
				size: file.size
				type: file.type

		# process events
		file.emit 'wait'
		@emit 'add', file


	# Create a `linkup.File` from a `window.File`, add it to the list of files and return it.
	send: (file) ->
		file = new linkup.File file
		@add file
		return file


	# Remove a `linkup.File` from the list of files.
	remove: (file) ->
		@_log "#{file.name}: currently being transferred; cannot remove", 'error' if @currentFile is file

		# remove file from list of files
		delete @files[file.id]
		@files.splice @files.indexOf(file), 1

		# process events
		file.emit 'init'
		@emit 'remove', file




	# Collect information about the transfer progress.
	status: () ->
		data =
			init: 0
			wait: 0
			transfer: 0
			complete: 0
			error: 0
			all: 0
			send:
				init: 0
				wait: 0
				transfer: 0
				complete: 0
				error: 0
				all: 0
			receive:
				init: 0
				wait: 0
				transfer: 0
				complete: 0
				error: 0
				all: 0
		for file in @files
			data[file.status]++
			data.all++
			data[file.mode][file.status]++
			data[file.mode].all++
		return data




	_onOpen: () ->
		# Send metadata of all queued files.
		for file in @files
			if file.status is 'init'
				@_sendCommand 'metadata', file,
					name: file.name
					size: file.size
					type: file.type


	_onClose: () ->
		# Set the status of all files that haven't been transferred to `error`.
		for file in @files
			if file.status isnt 'complete'
				file.emit 'error'

		# Close the PeerJS connections gracefully.
		if @_messages and @_messages.open
			@_messages.close()
		@_messages = null
		if @_data and @_data.open
			@_data.close()
		@_data = null




	# A helper function that sends a command to the connected peer.
	_sendCommand: (command, file, payload = {}) ->
		payload.id = file.id
		payload.command = command
		@_commandConnection.send JSON.stringify payload

		@_log "#{file.name}: `#{command}` command sent"


	# A helper function that handles all incoming commands from the connected peer.
	_onCommand: (data) =>
		# parse data
		data = JSON.parse data
		file = @files[data.id] or null

		@_log "#{if file then file.name else data.name}: `#{data.command}` command received"

		# handle command
		switch data.command
			when 'metadata'
				# add file to list of files
				file = new File
					id: data.id
					mode: 'receive'
					name: data.name
					size: data.size
					type: data.type
				@add file
			when 'receive'
				@currentFile = file
				file.emit 'transfer'
			when 'send'
				@currentFile = file
				file.emit 'transfer'
				@_sendData file
			when 'ack'
				file.emit 'complete'
				@currentFile = null
				@emit 'progress', file
			else
				@_log "invalid command: #{data.command}", 'error'




	# Send the data of a file to the connected peer.
	_sendData: (file) ->
		file.readAsBuffer (buffer) =>
			@_dataConnection.send buffer

		@_log "#{file.name}: sending data"


	# A helper function that handles the (file) data the connected peer sent.
	_onData: (buffer) =>
		file = @currentFile

		@_log "#{file.name}: data received"

		# send `ack` to confirm the data transfer
		@_sendCommand 'ack', file

		@currentFile = null
		file.saveFromBuffer buffer

		# process events
		file.emit 'complete'
		@emit 'progress', file




	# Check if there is anything to do. Called whenever a file gets added, sent, received.
	_checkSendCommand: (file) ->
		return if not @isOpen    # Abort if the peers are not connected.
		return if @currentFile    # Abort if there currently are files being transferred.

		# Look for a file whose data isn't sent yet.
		if @isController
			for file in @files
				if file.status is 'wait'    # We found a file.

					if @idle    # peer did nothing before
						@idle = false
						@emit 'transfer'
					@currentFile = file

					if file.mode is 'send'
						# If the file we are sending right now has just been added, its metadata might still be on the way. In this case, the peer doesn't now the id we send with the `receive` command.
						# todo: Fix this ugly timeout. A solution would by to confirm every command. The `receive` command and the data would then only be sent if the `metadata` has been confirmed. For example:
						# @_sendCommand 'metadata', file
						# 	cb -> @_sendCommand 'receive', file
						#		cb -> @_sendData file
						setTimeout () =>
							@_sendCommand 'receive', file
							@_sendData file
						, 100
					else
						@_sendCommand 'send', file

					# process events
					file.emit 'transfer'

					return    # abort loop

		# There is nothing to do right now.
		if not @idle    # We did something before.
			@idle = true
			@emit 'complete'




	# logging helper
	_log: (message, level = 'info') ->
		console[level] "[linkup.#{@constructor.name} ##{@id}] ", message





module.exports = Peer