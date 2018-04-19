## activeresource-response
### Addition to activeresource gem for HTTP header reading and request caching

Own forked version from Fivell. Noticed 404 wasn't being handled properly which caused an exception

This gem adds possibility to access http response (Net::HTTPResponse) object from result (single object or collection)
of activeresource call (methods : find, all, first, last, get )

#### Why It can be used?
Such functionallity can be used for easily implementing pagination in a REST API so that an ActiveResource client can navigate paginated results.

#### How to use?
Add dependency to your Gemfile

```ruby
gem "activeresource-response"
```

Just open your ActiveResource class  and add 

```ruby
add_response_method :your_method_name
```

You can add method to ActiveResource::Base to use it in all subclasses

```ruby
class ActiveResource::Base
  add_response_method :my_response  
end
```

You can remove method from ActiveResource subclass

```ruby
class Order < ActiveResource::Base
  remove_response_method  
end
```


**Caching** can be applied to paths; query parameters are ignored. Options are:
`regex` this will trigger the cache, and optional `expires_on`. There can
be multiple entries. There is debugging, look out for "[D]"

I applied caching within *activeresource-response* because Rails.cache was giving
me problems. You can't *Marshal.dump* objects with singleton methods which this gem does. This caches the raw JSON now

`namespace` is optional, it adds to the cache key. Can be a Lambda which returns a string

```ruby
  add_response_method :http_response, cache: [
    {regex: /\/path\.json$/, expires_in: 6.hours, namespace: 'namespace'}
  ]

```

## Full example of usage with kaminari gem

ActiveResource Class

```ruby
class Order < ActiveResource::Base
  self.format = :json
  self.site = 'http://0.0.0.0:3000/'
  self.element_name = "order" 
  add_response_method :http_response  # our new method for returned objects 
end
```

```ruby
Server Side

class OrdersController < ApplicationController
  def index
    @orders = Order.page(params[:page]).per(params[:per_page] || 10) #default 10 per page
    response.headers["X-total"] = @orders.total_count.to_s
    response.headers["X-offset"] = @orders.offset_value.to_s
    response.headers["X-limit"] = @orders.limit_value.to_s
    respond_with(@orders)
  end
end
```

Client Side

```ruby
class OrdersController < ApplicationController
  def index
    orders = Order.all(params: params)     
    @orders = Kaminari::PaginatableArray.new(orders,{
      limit: orders.http_response['X-limit'].to_i,
      offset: orders.http_response['X-offset'].to_i,
      total_count: orders.http_response['X-total'].to_i
    }) 
  end
end
```

### will_paginate compatibility
will_paginate has a little different API, so to populate headers 

```ruby
response.headers["X-total"] = @orders.total_entries.to_s
response.headers["X-offset"] = @orders.offset.to_s
response.headers["X-limit"] = @orders.per_page.to_s
``` 

On the API client side you might also use will_paginate, in that case you can just require will_paginate/array (in initializer for example)
 ```ruby
 orders = Order.all(params: params)     
 @orders = WillPaginate::Collection.create(params[:page] || 1, params[:per_page] || 10, orders.http_response['X-total'].to_i) do |pager|
  pager.replace orders
end
```

### Every time when http connection invoked ActiveResource connection object  stores http response. You can access it with http_response method. 
Example
```ruby
class Order < ActiveResource::Base
  self.site = 'http://0.0.0.0:3000/'
  self.element_name = "order" 
  add_response_method :my_response  # our new method 
end

orders = Order.all
first_order = Order.find(1) 
#see Net::HTTPResponse#[] method
orders.my_response['content-length'] 
# => "3831" 
first_order.my_response['content-length'] 
#=> "260"
#connection also always has last http response object , to access it use http_response method
Order.connection.http_response.to_hash
# => {"content-type"=>["application/json; charset=utf-8"], "x-ua-compatible"=>["IE=Edge"], "etag"=>["\"573cabd02b2f1f90405f7f4f77995fab\""], "cache-control"=>["max-age=0, private, must-revalidate"], "x-request-id"=>["2911c13a0c781044c474450ed789613d"], "x-runtime"=>["0.071018"], "content-length"=>["260"], "server"=>["WEBrick/1.3.1 (Ruby/1.9.2/2011-02-18)"], "date"=>["Sun, 19 Feb 2012 10:21:29 GMT"], "connection"=>["close"]} 
 ```
 
### Custom get method
You can access response from result of custom get method
Example
```ruby
class Country < ActiveResource::Base
  self.site = 'http://0.0.0.0:3000/'
  add_response_method :http  # our new method
end
cities = Country.find(1).get(:cities)
cities.http #method from Country class is available
``` 

### Headers and cookies methods 
You can get cookies and headers from response 
Example
```ruby
class Country < ActiveResource::Base
  self.site = 'http://0.0.0.0:3000/'
  add_response_method :my_response  # our new method
end
countries = Country.all
countries.my_response.headers

# collection with symbolized keys => {:content_type=>["application/json; charset=utf-8"], :x_ua_compatible=>["IE=Edge"], ..., :set_cookie=>["bar=foo; path=/", "foo=bar; path=/"]} 

countries.my_response.cookies
 # => {"bar"=>"foo", "foo"=>"bar"}   
 ```
 
### Note About Http response 
http response is object of ```Net::HTTPOK```, ```Net::HTTPClientError``` or one of other subclasses
of Net::HTTPResponse class. For more information see documentation  http://www.ruby-doc.org/stdlib-1.9.3/libdoc/net/http/rdoc/Net/HTTPResponse.html

### Testing with ActiveResource::HttpMock
Add this line to your test to patch http_mock

```ruby
 require "active_resource_response/http_mock"
```

### Contributing
  Fork it
  Create your feature branch (git checkout -b my-new-feature)
  Commit your changes (git commit -am 'Add some feature')
  Push to the branch (git push origin my-new-feature)
  Create new Pull Request