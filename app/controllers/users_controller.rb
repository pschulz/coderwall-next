class UsersController < ApplicationController
  before_action :require_login, only: [:edit, :update]
  skip_before_action :verify_authenticity_token, only: :show,
    if: ->{ request.format.json? }

  def show
    if params[:username].blank? && params[:id]
      @user = User.find(params[:id])
      return redirect_to(profile_path(username: @user.username))
    elsif params[:username] == 'random'
      @user = User.order("random()").first
    elsif params[:delete_account]
      return redirect_to(sign_in_url) unless signed_in?
      @user = current_user
    else
      @user = User.includes(:badges, :protips).find_by_username!(params[:username])
    end
    respond_to do |format|
      format.html
      format.json do
        if stale?(api_etag_keys_for_protip)
          response = params[:callback].present? ? {data: @user} : @user
          render(json: response, callback: params[:callback])
        end
      end
      format.all { head(:not_found) }
    end
  end

  def edit
    @user = User.where(id: params[:id]).first || current_user
    return head(:forbidden) if !current_user.can_edit?(@user)
  end

  def create
    return head(:forbidden) if signed_in?
    @user = User.new(new_user_params)
    if @user.save
      sign_in(@user)
      redirect_to finish_signup_url
    else
      render action: :new
    end
  end

  def index
    redirect_to sign_up_url
  end

  def update
    @user = User.find(params[:id])
    return head(:forbidden) if !current_user.can_edit?(@user)
    @user.attributes = user_params
    if @user.save
      redirect_to profile_url(username: @user.username)
    else
      render action: :edit
    end
  end

  def impersonate
    if Rails.env.development? || current_user.admin?
      user = User.find_by_username(params[:username])
      sign_in(user)
      redirect_to profile_url(username: user.username)
    end
  end

  def destroy
    @user = User.find(params[:id])
    head(:forbidden) unless current_user.can_edit?(@user)
    @user.destroy
    if @user == current_user
      sign_out
      flash[:notice] = "You are no longer signed in to Coderwall. Your acccount, #{@user.username}, has been deleted."
    else
      flash[:notice] = "#{@user.username}'s account deleted."
    end
    redirect_to(root_url)
  end

  protected

  def new_user_params
    params.require(:user).permit(:username, :password, :email)
  end

  def user_params
    safe_attributes = [
      :twitter,
      :github,
      :color,
      :email,
      :avatar,
      :title,
      :company,
      :location,
      :editable_skills,
      :about,
      :receive_newsletter,
      :receive_weekly_digest
    ]
    safe_attributes << :username if admin?
    params.require(:user).permit(safe_attributes)
  end

  def api_etag_keys_for_protip
    {
      etag:['v4', @user, params[:callback]],
      last_modified: @user.updated_at.utc,
      public: true
    }
  end

end
