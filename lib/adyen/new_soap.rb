require "net/https"

module Adyen
  module SOAP
    # from http://curl.haxx.se/ca/cacert.pem
    CACERT = File.expand_path('../../../support/cacert.pem', __FILE__)

    class << self
      # Username for the HTTP Basic Authentication that Adyen uses. Your username
      # should be something like +ws@Company.MyAccount+
      # @return [String]
      attr_accessor :username

      # Password for the HTTP Basic Authentication that Adyen uses. You can choose
      # your password yourself in the user management tool of the merchant area.
      # @return [String] 
      attr_accessor :password
    end

    class NewPaymentService
      LAYOUT = <<EOS
<?xml version="1.0"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <soap:Body>
    <ns1:authorise xmlns:ns1="http://payment.services.adyen.com">
      <ns1:paymentRequest>
        <merchantAccount xmlns="http://payment.services.adyen.com">%s</merchantAccount>
        <reference xmlns="http://payment.services.adyen.com">%s</reference>
%s
      </ns1:paymentRequest>
    </ns1:authorise>
  </soap:Body>
</soap:Envelope>
EOS

      AMOUNT_PARTIAL = <<EOS
        <amount xmlns="http://payment.services.adyen.com">
          <currency xmlns="http://common.services.adyen.com">%s</currency>
          <value xmlns="http://common.services.adyen.com">%s</value>
        </amount>
EOS

      CARD_PARTIAL = <<EOS
        <card xmlns="http://payment.services.adyen.com">
          <holderName>%s</holderName>
          <number>%s</number>
          <cvc>%s</cvc>
          <expiryYear>%s</expiryYear>
          <expiryMonth>%02d</expiryMonth>
        </card>
EOS

      ENDPOINT_URI = 'https://pal-%s.adyen.com/pal/servlet/soap/Payment'

      def self.endpoint
        @endpoint ||= URI.parse(ENDPOINT_URI % Adyen.environment)
      end

      attr_reader :params

      def initialize(params = {})
        @params = params
      end

      def amount_partial
        AMOUNT_PARTIAL % @params[:amount].values_at(:currency, :value)
      end

      def card_partial
        card  = @params[:card].values_at(:holder_name, :number, :cvc, :expiry_year)
        card << @params[:card][:expiry_month].to_i
        CARD_PARTIAL % card
      end

      def shopper_partial
        partials = []
        if shopper = @params[:shopper]
          if reference = shopper[:reference]
            partials << %{        <shopperReference xmlns="http://payment.services.adyen.com">#{reference}</shopperReference>}
          end
          if email = shopper[:email]
            partials << %{        <shopperEmail xmlns="http://payment.services.adyen.com">#{email}</shopperEmail>}
          end
          if ip = shopper[:ip]
            partials << %{        <shopperIP xmlns="http://payment.services.adyen.com">#{ip}</shopperIP>}
          end
        end
        partials.join("\n")
      end

      def authorise_payment_request_body
        LAYOUT % [@params[:merchant_account], @params[:reference], (amount_partial + card_partial + shopper_partial)]
      end

      def authorise_payment
        endpoint = self.class.endpoint

        post = Net::HTTP::Post.new(endpoint.path, 'Accept' => 'text/xml', 'Content-Type' => 'text/xml; charset=utf-8', 'SOAPAction' => 'authorise')
        post.basic_auth(Adyen::SOAP.username, Adyen::SOAP.password)
        post.body = authorise_payment_request_body

        request = Net::HTTP.new(endpoint.host, endpoint.port)
        request.use_ssl = true
        request.ca_file = CACERT
        request.verify_mode = OpenSSL::SSL::VERIFY_PEER

        request.start do |http|
          response = http.request(post)
          #p response
        end
      end
    end
  end
end
