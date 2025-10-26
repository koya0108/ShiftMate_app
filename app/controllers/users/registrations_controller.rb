class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |resource|
      if resource.errors.any?
        flash[:alert] = "入力に不備があります。フォーム内容を確認してください。"
      end
    end
  end
end
