class InvitationsController < InertiaController
  def reset
    group = current_user.groups.find(params[:group_id])
    return render_error(403, "Only the group owner can replace its invitation code.") unless group.owner_id == current_user.id

    group.reset_invitation!
    redirect_to group_path(group), notice: "Invitation replaced. The previous code no longer works.", status: :see_other
  end
end
