module Api
  module V1
    class BaseController < ApplicationController
      
      before_filter :restrict_access
      
      private
      
      def restrict_access
        authenticate_or_request_with_http_token do |token, options|
          ApiKey.exists?(access_token: token)
        end
      end

      def current_user
        if doorkeeper_token
          @current_user ||= User.find(doorkeeper_token.resource_owner_id)
        end
      end
      
    end
  end
end