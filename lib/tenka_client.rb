# Copyright © 2017 Rekka Labs (https://rekka.io/)
# See LICENSE for licensing information.

%w(
	json

	uri cgi net/http
	set
).each &method(:require)

module Tenka
	# The main class for the client.
	# TODO:  Provide usage examples here.
	class Client
		# The defaults when initializing a client.
		# `host` specifies the hostname to connect to.  You probably won't
		# need to change this.
		# `ssl` turns HTTPS on or off.  If you are using an API key, you
		# probably want to leave it on.
		# `port` specifies the port to connect to.  
		DefaultOpts = {
			host: 'api.tenka.io',
			port: 443,
			ssl: true,
			api_key: nil,
		}.freeze
		DefaultOpts.each_key { |k| define_method(k) { opts[k] } }

		# For endpoints that require units to be specified, this is the
		# list of units.
		Units = Set.new %w(
			mile
			km
		)

		attr_accessor :opts, :last_resp,
			:last_error,
			:rate_limit_calls_left,
			:api_tokens_left

		# Creates a new client.  To simplify the API, the client carries
		# information in the form of state, and thus is not thread-safe;
		# you should instantiate one client per thread that accesses Tenka.
		def initialize opts = {}
			self.opts = DefaultOpts.merge(opts)

			# If they don't specify a port but they do turn off SSL, we set
			# the port to 80.
			if !opts.has_key?(port) && !ssl
				self.opts[:port] = 80
			end
		end

		def last_error
			return nil if !last_resp || last_resp.code[0] == '2'
			h = begin
				JSON.parse(last_resp.body)
			rescue JSON::ParserError => e
				# TODO:  Might wanna dependency-inject a logger for cases
				# like this.
				return nil
			end

			h
		end

		# The individual endpoints follow:

		# Reverse-geocode a latitude/longitude pair.
		def containing_lat_long lat, long
			ok, body = get('/containing/lat-long', lat: lat, long: long)
			ok && body
		end
		alias_method :containing_lat_lon, :containing_lat_long

		# Reverse-geocode a ZIP code centroid.  (Tenka only supports US ZIPs
		# for now, but this is not enforced client-side.)
		# 
		# Note that ZIP codes often describe very odd shapes; they are based
		# on postal service routes rather than geographical boundaries.
		# As a result, the centroid may lie in a different city than any
		# single point within the actual boundaries of the ZIP code.  (ZIP
		# centroids are popular because of their granularity, but they should
		# be used with caution.)
		# 
		# ZIP codes can start with leading zeroes.  It is advised to
		# use a string to represent a ZIP code rather than an integer.
		def containing_zip zip
			ok, body = get('/containing/zip', zip: zip)
			ok && body
		end

		# Returns a list of ZIP codes whose centroids are within a given
		# radius of another ZIP code's centroid.  (See the remarks about
		# centroids in #containing_zip.)
		def nearby_zip zip, radius, units = 'mile'
			unless Units.include?(units)
				raise ArgumentError, "Invalid unit #{units}.  Must be one "\
					"of #{Units.to_a.join(', ')}."
			end
			ok, body = get('/nearby/zip',
				zip: zip, radius: radius, units: units)
			ok && body['zips']
		end

		# Returns the number of calls your API token has left, as well as
		# how many calls you can make before you hit the rate limit for the
		# server.
		# 
		# This information is automatically gathered (whether your API key
		# is valid or not) on every request, so you can also just check
		# Tenka::Client#rate_limit_calls_left and Tenka::Client#api_tokens_left.
		# 
		# Making a request against this endpoint does not reduce the number
		# of API tokens you have left.  (It does count towards the rate limit.)
		# 
		# A 404 from this endpoint indicates that your API key is invalid.
		def calls_left
			ok, body = get('/tokens-remaining')
			ok && {
				rate_limit: rate_limit_calls_left,
				api_limit: api_tokens_left,
			}
		end

		private

		def get path, query = nil
			req_headers = {}
			if api_key
				req_headers['API-Token'] = api_key
			end
			path = path + h2query(query) if query
			http_req Net::HTTP::Get.new(path, req_headers)
		end

		# Returns [true/false, parsed_body, response_object].
		def http_req req, body = nil
			resp = Net::HTTP.start(host, port, use_ssl: ssl) { |h|
				h.request req, body
			}
			body = JSON.parse(resp.body)
			self.last_resp = resp
			update_counters!

			# Error detection is easy for Tenka.
			[resp.code[0] == '2', body]
		end

		# Check rate limits and API tokens remaining in the headers that came
		# back; 
		def update_counters!
			if l = last_resp['rate-limit-calls-left']
				self.rate_limit_calls_left = l.to_i
			end

			if l = last_resp['api-token-calls-remaining']
				self.api_tokens_left = l.to_i
			end
		end

		def server_uri
			# Under normal circumstances, `host` shouldn't change (just start
			# a new client).
			@_server_uri ||= URI("#{ssl ? 'https' : 'http'}#{host}/")
		end

		def h2query h
			'?' <<
			h.map { |k,v|
				(CGI.escape(k.to_s) << '=' << CGI.escape(v.to_s)).
					gsub('+', '%20')
			}.join('&')
		end
	end
end
