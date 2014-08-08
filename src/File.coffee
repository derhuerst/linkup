# linkup
# A JavaScript library providing dead simple file sharing via WebRTC DataChannels.
# Jannis R <jannisr.de>
# v0.1.0





# dependencies
uid = require './uid.coffee'
EventEmitter = require './EventEmitter.coffee'





class File extends EventEmitter


	id: null
	mode: null    # send or receive
	status: null
	# init: waiting to send metadata
	# wait: waiting to send/receive data
	# transfer: sending/receiving the data
	# complete: data sent/received
	# error: an error occured

	file: null

	name: null
	size: null
	type: null


	constructor: (options) ->
		super    # call super class constructor

		@id = options.id or uid 9
		if options instanceof window.File
			@file = options
			@mode = 'send'
		else if options.file instanceof window.File
			@file = options.file
			@mode = 'send'
		else
			@mode = 'receive'

		@name = options.name or @file.name
		@size = options.size or @file.size
		@type = options.type or @file.type

		@on 'init', () =>
			@status = 'init'
		@on 'wait', () =>
			@status = 'wait'
		@on 'transfer', () =>
			@status = 'transfer'
		@on 'complete', () =>
			@status = 'complete'
		@on 'error', () =>
			@status = 'error'

		@emit 'init'


	readAsBuffer: (callback) ->
		reader = new FileReader()
		reader.onload = () ->
			callback reader.result
		reader.readAsArrayBuffer @file

	saveFromBuffer: (buffer) ->
		blob = new Blob [buffer],
			type: @type
		saveAs blob, @name    # polyfilled by FileSaver.js





module.exports = File