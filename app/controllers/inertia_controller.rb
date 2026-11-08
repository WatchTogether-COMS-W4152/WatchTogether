# frozen_string_literal: true

class InertiaController < ApplicationController
  inertia_share do
    {
      auth: { user: current_user&.as_json(only: [ :id, :display_name, :email ]) },
      flash: flash.to_hash.slice("notice", "alert")
    }
  end
end
