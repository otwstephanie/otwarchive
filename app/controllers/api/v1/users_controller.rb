class UsersController < Api::BaseController


    private

    def user_params
      params.require(:user).permit(:title)
    end

    def query_params
      # this assumes that an album belongs to an artist and has an :artist_id
      # allowing us to filter by this
      params.permit(:artist_id, :title)
    end


end