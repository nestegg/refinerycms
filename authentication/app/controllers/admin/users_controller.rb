module Admin
  class UsersController < Admin::BaseController

    crudify :user, :order => 'login', :title_attribute => 'login'

    before_filter :load_available_plugins_and_roles, :only => [:new, :create, :edit, :update]

    layout 'admin'

    def index
      search_all_users if searching?
      paginate_all_users

      render :partial => 'users' if request.xhr?
    end

    def new
      @user = User.new
      @selected_plugin_names = []
    end

    def create
      @user = User.new(params[:user])
      @selected_plugin_names = params[:user][:plugins] || []
      @selected_role_names = params[:user][:roles] || []

      if @user.save
        @user.plugins = @selected_plugin_names
        # if the user is a superuser and can assign roles according to this site's
        # settings then the roles are set with the POST data.
        unless current_user.has_role?(:superuser) and RefinerySetting.find_or_set(:superuser_can_assign_roles, false)
          @user.add_role(:refinery)
        else
          @user.roles = @selected_role_names.collect{|r| Role[r.downcase.to_sym]}
        end

        redirect_to(admin_users_url, :notice => t('refinery.crudify.created', :what => @user.login))
      else
        render :action => 'new'
      end
    end

    def edit
      @user = User.find params[:id]
      @selected_plugin_names = @user.plugins.collect{|p| p.name}
    end

    def update
      # Store what the user selected.
      @selected_role_names = params[:user].delete(:roles) || []
      unless current_user.has_role?(:superuser) and RefinerySetting.find_or_set(:superuser_can_assign_roles, false)
        @selected_role_names = @user.roles.collect{|r| r.title}
      end
      @selected_plugin_names = params[:user][:plugins]

      # Prevent the current user from locking themselves out of the User manager
      if current_user.id == @user.id and (params[:user][:plugins].exclude?("refinery_users") || @selected_role_names.map(&:downcase).exclude?("refinery"))
        flash.now[:error] = t('admin.users.update.cannot_remove_user_plugin_from_current_user')
        render :action => "edit"
      else
        # Store the current plugins and roles for this user.
        @previously_selected_plugin_names = @user.plugins.collect{|p| p.name}
        @previously_selected_roles = @user.roles
        @user.roles = @selected_role_names.collect{|r| Role[r.downcase.to_sym]}

        if @user.update_attributes(params[:user])
          redirect_to admin_users_url, :notice => t('refinery.crudify.updated', :what => @user.login)
        else
          @user.plugins = @previously_selected_plugin_names
          @user.roles = @previously_selected_roles.collect{|r| Role[r.downcase.to_sym]}
          @user.save
          render :action => 'edit'
        end
      end
    end

  protected

    def load_available_plugins_and_roles
      @available_plugins = ::Refinery::Plugins.registered.in_menu.collect{|a|
        {:name => a.name, :title => a.title}
      }.sort_by {|a| a[:title]}

      @available_roles = Role.find(:all)
    end

  end
end