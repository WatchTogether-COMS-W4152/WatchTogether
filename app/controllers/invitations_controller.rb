class InvitationsController < InertiaController
  def reset
    group = current_user.groups.find(params[:group_id])
    group.with_lock do
      return render_error(403, "Only group owners can replace the invitation code.") unless group.owner?(current_user)

      group.reset_invitation!
    end
    redirect_to group_path(group), notice: "Invitation replaced. The previous code no longer works.", status: :see_other
  end
end
