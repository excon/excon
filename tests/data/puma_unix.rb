# On JRuby, puma's reactor intermittently misses requests arriving on unix
# sockets, leaving them unanswered until the client times out. Hand each
# connection straight to a worker thread instead.
queue_requests false
