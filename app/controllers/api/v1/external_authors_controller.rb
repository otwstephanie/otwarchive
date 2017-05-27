class ExternalAuthorsController < Api::BaseController


    private

    def external_author_params
      params.require(:external_author).permit(:title)
    end

    def query_params
      # this assumes that an album belongs to an artist and has an :artist_id
      # allowing us to filter by this
      params.permit(:artist_id, :title)
    end


end