module Spree
  class PaypalCheckout::OrdersController < StoreController
    skip_before_action :verify_authenticity_token

    def create
      @order = current_order || Spree::Order.find_by!(number: params[:order_number])

      if payment_method.preferred_test_mode
        environment = PayPal::SandboxEnvironment.new(payment_method.preferred_paypal_client_id, payment_method.preferred_paypal_client_secret)
      else
        environment = PayPal::LiveEnvironment.new(payment_method.preferred_paypal_client_id, payment_method.preferred_paypal_client_secret)
      end

      client = PayPal::PayPalHttpClient.new(environment)

      request = PayPalCheckoutSdk::Orders::OrdersCreateRequest::new
      request.request_body({
        intent: payment_method.intent,
        purchase_units: [{
          reference_id: @order.number,
          amount: {
            currency_code: @order.currency,
            value: @order.total
          },
          shipping: {
            address: {
              address_line_1: @order.ship_address.address1,
              address_line_2: @order.ship_address.address2,
              admin_area_2: @order.ship_address.city,
              admin_area_1: @order.ship_address.state_text,
              postal_code: @order.ship_address.zipcode,
              country_code: @order.ship_address.country_iso
            }
          }
        }],
        payment_source: {
          paypal: {
            experience_context: {
              brand_name: current_store.name,
              shipping_preference: "SET_PROVIDED_ADDRESS"
            },
            name: {
              given_name: @order.ship_address.firstname,
              surname:@order.ship_address.lastname
            }
          }
        }
      })

      begin
        response = client.execute(request)
        order = response.result
        render json: { id: order.id, status: order.status, intent: order.intent }
      rescue PayPalHttp::HttpError => ioe
        render json: { debug_id: ioe.headers["paypal-debug-id"] }, status: ioe.status_code
      end
    end

    private

    def paypal_checkout(order, provider)
      @paypal_checkout ||= PaypalServices::Checkout.new(order, provider)
    end

    def payment_method
      Spree::PaymentMethod.find_by(type: "Spree::Gateway::PaypalCheckout")
    end
  end
end
