require_relative "test_helper"

class ControllerTest < ActionDispatch::IntegrationTest
  def test_works
    get products_url
    assert_response :success

    assert_equal 1, Ahoy::Visit.count
    assert_equal 1, Ahoy::Event.count

    event = Ahoy::Event.last
    assert_equal "Viewed products", event.name
    assert_equal({}, event.properties)
  end

  def test_standard
    referrer = "http://www.example.com"
    get products_url, headers: {"Referer" => referrer}

    visit = Ahoy::Visit.last
    assert_equal referrer, visit.referrer
    assert_equal "www.example.com", visit.referring_domain
    assert_equal "http://www.example.com/products", visit.landing_page
    assert_equal "127.0.0.1", visit.ip
  end

  def test_utm_params
    get products_url(
      utm_source: "test-source",
      utm_medium: "test-medium",
      utm_term: "test-term",
      utm_content: "test-content",
      utm_campaign: "test-campaign"
    )

    visit = Ahoy::Visit.last
    assert_equal "test-source", visit.utm_source
    assert_equal "test-medium", visit.utm_medium
    assert_equal "test-term", visit.utm_term
    assert_equal "test-content", visit.utm_content
    assert_equal "test-campaign", visit.utm_campaign
  end

  def test_tech
    user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:78.0) Gecko/20100101 Firefox/78.0"
    get products_url, headers: {"User-Agent" => user_agent}

    visit = Ahoy::Visit.last
    assert_equal user_agent, visit.user_agent
    assert_equal "Firefox", visit.browser
    assert_equal "Mac", visit.os
    assert_equal "Desktop", visit.device_type
  end

  def test_legacy_user_agent_parser
    with_options(user_agent_parser: :legacy) do
      user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:78.0) Gecko/20100101 Firefox/78.0"
      get products_url, headers: {"User-Agent" => user_agent}

      visit = Ahoy::Visit.last
      assert_equal user_agent, visit.user_agent
      assert_equal "Firefox", visit.browser
      assert_equal "Mac OS X", visit.os
      assert_equal "Desktop", visit.device_type
    end
  end

  def test_visitable
    post products_url
    visit = Ahoy::Visit.last
    assert_equal visit, Product.last.ahoy_visit
  end

  def test_instance
    post products_url
    assert_response :success

    assert_equal 1, Ahoy::Visit.count
    assert_equal 1, Ahoy::Event.count

    event = Ahoy::Event.last
    assert_equal "Created product", event.name
    product = Product.last
    assert_equal({"product_id" => product.id}, event.properties)
  end

  def test_mask_ips
    with_options(mask_ips: true) do
      get products_url
      assert_equal "127.0.0.0", Ahoy::Visit.last.ip
    end
  end

  def test_skip_before_action
    get no_visit_products_url
    assert_equal 0, Ahoy::Visit.count
  end

  def test_server_side_visits_true
    with_options(server_side_visits: true) do
      get list_products_url
      assert_equal 1, Ahoy::Visit.count
    end
  end

  def test_server_side_visits_false
    with_options(server_side_visits: false) do
      get products_url
      assert_equal 0, Ahoy::Visit.count
      assert_equal ["ahoy_track", "ahoy_visit", "ahoy_visitor"], response.cookies.keys.sort
    end
  end

  def test_server_side_visits_when_needed
    with_options(server_side_visits: :when_needed) do
      get list_products_url
      assert_equal 0, Ahoy::Visit.count
      get products_url
      assert_equal 1, Ahoy::Visit.count
    end
  end

  def test_api_only
    with_options(api_only: true) do
      get list_products_url
      assert_equal 0, Ahoy::Visit.count
      assert_empty response.cookies
    end
  end

  def test_visit_duration
    get products_url
    travel 5.hours do
      get products_url
    end
    assert_equal 2, Ahoy::Visit.count
    assert_equal 1, Ahoy::Visit.pluck(:visitor_token).uniq.count
  end

  def test_visit_duration_cookies_false
    with_options(cookies: false) do
      get products_url
      travel 5.hours do
        get products_url
      end
      assert_equal 1, Ahoy::Visit.count
      assert_equal 1, Ahoy::Visit.pluck(:visitor_token).uniq.count
    end
  end

  def test_visitor_duration
    get products_url
    travel 3.years do
      get products_url
    end
    assert_equal 2, Ahoy::Visit.count
    assert_equal 2, Ahoy::Visit.pluck(:visitor_token).uniq.count
  end

  def test_visitor_duration_cookies_false
    with_options(cookies: false) do
      get products_url
      travel 3.years do
        get products_url
      end
      assert_equal 1, Ahoy::Visit.count
      assert_equal 1, Ahoy::Visit.pluck(:visitor_token).uniq.count
    end
  end

  def test_token_generator
    token_generator = -> { "test-token" }
    with_options(token_generator: token_generator) do
      get products_url
      visit = Ahoy::Visit.last
      assert_equal "test-token", visit.visit_token
      assert_equal "test-token", visit.visitor_token
    end
  end

  def test_bad_visit_cookie
    make_request(cookies: {"ahoy_visit" => "badtoken\255"})
    assert_equal ahoy.visit_token, "badtoken"
  end

  def test_bad_visitor_cookie
    make_request(cookies: {"ahoy_visitor" => "badtoken\255"})
    assert_equal ahoy.visitor_token, "badtoken"
  end

  def test_bad_visit_header
    make_request(headers: {"Ahoy-Visit" => "badtoken\255"})
    assert_equal ahoy.visit_token, "badtoken"
  end

  def test_bad_visitor_header
    make_request(headers: {"Ahoy-Visitor" => "badtoken\255"})
    assert_equal ahoy.visitor_token, "badtoken"
  end

  private

  def make_request(cookies: {}, headers: {})
    cookies.each do |k, v|
      self.cookies[k] = v
    end
    get products_url, headers: headers
    assert_response :success
  end

  def ahoy
    controller.ahoy
  end
end
