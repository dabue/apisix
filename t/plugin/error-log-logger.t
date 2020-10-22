#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use t::APISIX 'no_plan';

repeat_each(1);
no_long_string();
no_root_location();

add_block_preprocessor(sub {
    my ($block) = @_;

    my $stream_single_server = <<_EOC_;
    # fake server, only for test
    server {
        listen 33333;

        content_by_lua_block {
            local exiting = ngx.worker.exiting
            local sock, err = ngx.req.socket(true)
            if not sock then
                ngx.log(ngx.WARN, "socket error:" .. err)
                return
            end
            sock:settimeout(30 * 1000)
            while(not exiting())
            do
                local data, err =  sock:receive()
                if (data) then
                    ngx.log(ngx.INFO, "[Server] receive data:" .. data)
                else 
                    if err ~= "timeout" then
                        ngx.log(ngx.WARN, "socket error:" .. err)
                        return
                    end
                end
            end
        }
    }
_EOC_

    $block->set_value("stream_config", $stream_single_server);
});


add_block_preprocessor(sub {
    my ($block) = @_;

    my $stream_default_server = <<_EOC_;
	    content_by_lua_block {
	    	echo "hello";
	    }
_EOC_

    $block->set_value("stream_server_config", $stream_default_server);
});

run_tests;

__DATA__

=== TEST 1: log a warn level message
--- config
    location /t {
        content_by_lua_block {
            local core = require("apisix.core")
            core.log.warn("this a warning message for test.")
        }
    }
--- request
GET /t
--- response_body
--- error_log eval
qr/\[Server\] receive data:.*this a warning message for test./



=== TEST 2: log an error level message
--- config
    location /t {
        content_by_lua_block {
            local core = require("apisix.core")
            core.log.warn("this an error message for test.")
        }
    }
--- request
GET /t
--- response_body
--- error_log eval
qr/\[Server\] receive data:.*this an error message for test./



=== TEST 3: log an info level message
--- config
    location /t {
        content_by_lua_block {
            local core = require("apisix.core")
            core.log.info("this an info message for test.")
        }
    }
--- request
GET /t
--- response_body
--- no_error_log
[Server] receive data
