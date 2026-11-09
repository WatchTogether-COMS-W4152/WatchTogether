class MembershipsController < InertiaController
  def promote
    group = current_user.groups.find(params[:group_id])
    group.with_lock do
      return render_error(403, "Only group owners can manage members.") unless group.owner?(current_user)

      membership = group.memberships.includes(:user).find_by!(user_id: params[:user_id])
      membership.update!(role: "owner")
      redirect_to group_path(group), notice: "#{membership.user.display_name} is now an owner.", status: :see_other
    end
  end

  def destroy
    group = current_user.groups.find(params[:group_id])
    group.with_lock do
      return render_error(403, "Only group owners can manage members.") unless group.owner?(current_user)

      membership = group.memberships.includes(:user).find_by!(user_id: params[:user_id])
      if membership.user_id == current_user.id
        return redirect_to group_path(group), alert: "You cannot remove yourself. A group must keep at least one owner.", status: :see_other
      end

      membership.destroy!
      group.reset_invitation!
      redirect_to group_path(group), notice: "#{membership.user.display_name} was removed. The invitation code has been replaced.", status: :see_other
    end
  end
end
