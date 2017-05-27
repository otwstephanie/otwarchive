module Api
  # Version the API explicitly in the URL to allow different versions with breaking changes to co-exist if necessary.
  # The roll over to the next number should happen when code written against the old version will not work
  # with the new version.
  module V1
    class BaseController < ApplicationController
      before_filter :restrict_access
      before_action :set_resource, only: [:destroy, :show, :update, :create]
      respond_to :json

      private


      # Returns the resource from the created instance variable
      # @return [Object]
      def get_resource
        instance_variable_get("@#{resource_name}")
      end

      # Returns the allowed parameters for searching
      # Override this method in each API controller
      # to permit additional parameters to search on
      # @return [Hash]
      def query_params
        {}
      end

      # Returns the allowed parameters for pagination
      # @return [Hash]
      def page_params
        params.permit(:page, :page_size)
      end

      # The resource class based on the controller
      # @return [Class]
      def resource_class
        @resource_class ||= resource_name.classify.constantize
      end

      # The singular name for the resource class based on the controller
      # @return [String]
      def resource_name
        @resource_name ||= self.controller_name.singularize
      end

      # Only allow a trusted parameter "white list" through.
      # If a single resource is loaded for #create or #update,
      # then the controller for the resource must implement
      # the method "#{resource_name}_params" to limit permitted
      # parameters for the individual model.
      def resource_params
        @resource_params ||= self.send("#{resource_name}_params")
      end
      # POST /api/{plural_resource_name}
      def create
        set_resource(resource_class.new(resource_params))

        if get_resource.save
          render :show, status: :created
        else
          render json: get_resource.errors, status: :unprocessable_entity
        end
      end

      # DELETE /api/{plural_resource_name}/1
      def destroy
        get_resource.destroy
        head :no_content
      end

      # GET /api/{plural_resource_name}
      def index
        plural_resource_name = "@#{resource_name.pluralize}"
        resources = resource_class.where(query_params)
                        .page(page_params[:page])
                        .per(page_params[:page_size])

        instance_variable_set(plural_resource_name, resources)
        respond_with instance_variable_get(plural_resource_name)
      end

      # GET /api/{plural_resource_name}/1
      def show
        respond_with get_resource
      end

      # PATCH/PUT /api/{plural_resource_name}/1
      def update
        if get_resource.update(resource_params)
          render :show
        else
          render json: get_resource.errors, status: :unprocessable_entity
        end
      end
      # Use callbacks to share common setup or constraints between actions.
      def set_resource(resource = nil)
        resource ||= resource_class.find(params[:id])
        instance_variable_set("@#{resource_name}", resource)
      end

      # Look for a token in the Authorization header only and check that the token isn't currently banned
      def restrict_access
        authenticate_or_request_with_http_token do |token, _|
          ApiKey.exists?(access_token: token) && !ApiKey.find_by(access_token: token).banned?
        end
      end

      # Top-level error handling: returns a 403 forbidden if a valid archivist isn't supplied and a 400
      # if no works are supplied. If there is neither a valid archivist nor valid works, a 400 is returned
      # with both errors as a message
      def batch_errors(archivist, import_items)
        status = :bad_request
        errors = []

        unless archivist && archivist.is_archivist?
          status = :forbidden
          errors << "The 'archivist' field must specify the name of an Archive user with archivist privileges."
        end

        if import_items.nil? || import_items.empty?
          errors << "No items to import were provided."
        elsif import_items.size >= ArchiveConfig.IMPORT_MAX_WORKS_BY_ARCHIVIST
          errors << "This request contains too many items to import. A maximum of #{ ArchiveConfig.IMPORT_MAX_WORKS_BY_ARCHIVIST } " +
            "items can be imported at one time by an archivist."
        end
        status = :ok if errors.empty?
        [status, errors]
      end
    end
  end
end
