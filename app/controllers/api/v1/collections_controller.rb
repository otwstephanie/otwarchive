class CollectionsController < Api::BaseController


    private

    def collection_params
      params.require(:collection).permit(:title)
    end

    def query_params
      # this assumes that an album belongs to an artist and has an :artist_id
      # allowing us to filter by this
      params.permit(:artist_id, :title)
    end


end