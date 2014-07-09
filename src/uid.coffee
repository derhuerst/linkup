# linkup
# A JavaScript library providing dead simple file sharing via WebRTC DataChannels.
# Jannis R <jannisr.de>
# v0.1.0





uid = (n, s) ->
	# Shortest possible UUID generator
	# Leon Ochmann <leonochmann@outlook.com>, Jannis R <mail@jannisr.de>
	s = (Math.random() * 26 + 10 | 0).toString 36    # random letter
	while --n
		s += (Math.random() * 36 | 0).toString 36    # random letter or digit
	return s





exports.uid = uid