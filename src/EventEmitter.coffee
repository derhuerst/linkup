# linkup
# A JavaScript library providing dead simple file sharing via WebRTC DataChannels.
# Jannis R <jannisr.de>
# v0.1.0





# tiny event emitter
# Jannis R <mail@jannisr.de>
# https://gist.github.com/derhuerst/5433f5ee3342a1de6d81
class EventEmitter


	_events: null


	constructor: () ->
		@_events = {}


	emit: (event, data) ->
		if @_events[event]
			for handler in @_events[event]
				handler.call this, data
		return this

	on: (event, handler) ->
		@_events[event]?=[]
		@_events[event].push handler

	once: (event, handler) ->
		fn = (data) ->
			@removeListener event, fn
			handler data
		@on event, fn





module.exports = EventEmitter