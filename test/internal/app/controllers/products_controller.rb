class ProductsController < ActionController::Base
  def index
    ahoy.track "Viewed products"
    head :ok
  end

  def list
    head :ok
  end

  def create
    Product.create!
    head :ok
  end

  def authenticate
    ahoy.authenticate(User.last)
    head :ok
  end

  private

  def current_user
    @current_user ||= User.last
  end
end
