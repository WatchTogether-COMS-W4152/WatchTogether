class MembershipsController < InertiaController
  def promote
    group = current_user.groups.find(params[:group_id])
    group.with_lock do
      return render_error(403, "Only group owners can manage members.") unless group.owner?(current_user)

      membership = group.memberships.includes(:user).find_by!(user_id: params[:user_id])
      membership.update!(role: "owner")
      redirect_to group_members_path(group), notice: "#{membership.user.display_name} is now an owner.", status: :see_other
    end
  end

  def leave
    group = current_user.groups.find(params[:group_id])
    group.with_lock do
      membership = group.memberships.find_by!(user: current_user)
      if membership.owner? && group.memberships.owner.count == 1
        message = group.memberships.count == 1 ? "You're the only member. Delete the group instead." : "Make someone else an owner before you leave."
        return redirect_to group_members_path(group), alert: message, status: :see_other
      end

      membership.destroy!
    end
    redirect_to groups_path, notice: "You left #{group.name}.", status: :see_other, inertia: { clear_history: true }
  end

  def destroy
    group = current_user.groups.find(params[:group_id])
    group.with_lock do
      return render_error(403, "Only group owners can manage members.") unless group.owner?(current_user)

      membership = group.memberships.includes(:user).find_by!(user_id: params[:user_id])
      if membership.user_id == current_user.id
        return redirect_to group_members_path(group), alert: "Use Leave group to leave.", status: :see_other
      end

      membership.destroy!
      group.reset_invitation!
      redirect_to group_members_path(group), notice: "#{membership.user.display_name} was removed. The invitation code changed.", status: :see_other
    end
  end
end
