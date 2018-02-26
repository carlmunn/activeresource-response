require_relative 'test_helper'

class ActiveResourceResponseTest < MiniTest::Test

  def setup

    @country = {:country => {:id => 1, :name => "Ukraine", :iso=>"UA"}}
    @city    = {:city => {:id => 1, :name => "Odessa", :population => 2500000}}
    @region  = {:region => {:id => 1, :name => "Odessa region", :population => 4500000}}
    @street  = {:street => {:id => 1, :name => "Deribasovskaya", :population => 2300}}
    
    @country_create_error = {:errors => {:base => ["country exists"]}}

    # Quick response generator
    _response = ->(uri, records, others={}, status: 200){
      [uri, {}, records.to_json, status, {"X-total" => "1"}.merge!(others)]
    }

    ActiveResource::HttpMock.respond_to do |mock|
      mock.get(*_response["/countries.json", [@country]])
      mock.get(*_response["/regions.json", [@region]])
      mock.get(*_response["/regions/1.json", @region])
      mock.get(*_response["/regions/population.json", {:count => 45000000}])
      mock.get(*_response["/regions/cities.json", [@city], {"X-total"=>'2'}])
      mock.get(*_response["/countries/1.json", @country, {'Set-Cookie'=>["foo=bar;bar=foo;path=/"]}])
      mock.get(*_response["/countries/1/population.json", {:count => 45000000}])
      mock.get(*_response["/countries/1/cities.json", [@city]])
      mock.get(*_response["/regions/1/cities.json", [@city]])
      mock.get(*_response["/cities/1/population.json", {:count => 2500000}])
      mock.get(*_response["/cities/1.json", @city])
      mock.get(*_response["/cities.json", [@city]])
      mock.get(*_response["/streets.json", [@street]])
      mock.get(*_response["/streets/1/city.json", @city])
      mock.get(*_response["/streets/1.json", @street])
      mock.post(*_response["/countries.json", @country_create_error, status: 422])
    end
  end

  def test_methods_appeared
    countries = Country.all
    assert countries.respond_to?(:http)
    assert countries.http.respond_to?(:cookies)
    assert countries.http.respond_to?(:headers)
    assert Country.respond_to?(:http_response)
    regions = Region.all
    assert regions.respond_to?(:http_response)
  end

  def test_get_headers_from_all
    countries = Country.all
    assert_kind_of Country, countries.first
    assert_equal "UA", countries.first.iso
    assert_equal countries.http.headers[:x_total].first.to_i, 1
  end

  def test_headers_from_custom
    cities = Region.get("cities")
    assert cities.respond_to?(:http_response)
    assert_equal cities.http_response.headers[:x_total].first.to_i, 2
    assert_equal cities.http_response['X-total'].to_i, 2
    country_population = Country.find(1).get("population")

    #immutable objects doing good
    some_numeric = 45000000

    assert_equal country_population["count"], some_numeric
    assert country_population.respond_to?(:http)
    assert !some_numeric.respond_to?(:http)

    assert_equal Country.connection.http_response.headers[:x_total].first.to_i, 1
    assert_equal Country.http_response.headers[:x_total].first.to_i, 1
    assert_equal Country.http_response['X-total'].to_i, 1
    
    cities = Country.find(1).get("cities")
    assert cities.respond_to?(:http), "Cities should respond to http"
    assert_equal cities.http.headers[:x_total].first.to_i, 1, "Cities total value should be 1"
    
    regions_population = Region.get("population")
    assert_equal regions_population['count'], 45000000
    cities = Region.find(1).get("cities")
    assert cities.respond_to?(:http_response)
    assert_equal cities.http_response.headers[:x_total], ['1']
  end

  def test_methods_without_http
    cities = City.all
    assert_kind_of City, cities.first
    country_population = Country.find(1).get("population")
    assert_equal 45000000, country_population["count"].to_i
  end

  def test_get_headers_from_find
    country = Country.find(1)
    assert_equal country.http.headers[:x_total], ['1']
  end

  def test_get_cookies
    country = Country.find(1)
    assert_equal 'bar', country.http.cookies['foo']
    assert_equal 'foo', country.http.cookies['bar']
    assert_equal 'bar', Country.http_response.cookies['foo']
    assert_equal 'foo', Country.http_response.cookies['bar']
  end

  def test_headers_after_exception
    country = Country.create(@country[:country])
    assert_equal Country.http_response.headers[:x_total], ['1']
    assert_equal Country.http_response.code, 422
    assert_equal country.errors.full_messages.count ,1
    assert_equal country.errors.count ,1
  end

  def test_remove_method
     street  = Street.find(:first)
     assert !(street.respond_to?(ActiveResourceResponseBase.http_response_method))
     city = Street.find(1).get('city')
     assert !(city.respond_to?(ActiveResourceResponseBase.http_response_method))
     #test if all ok in base class
     country = Country.find(1)
     assert country.respond_to?(Country.http_response_method)
     region = Region.find(1)
     assert region.respond_to?(ActiveResourceResponseBase.http_response_method)
  end
  
  def test_model_naming_methods
      street = Country.find(1)
      assert street.class.respond_to?(:model_name)
  end
end