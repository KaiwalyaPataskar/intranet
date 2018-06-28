class CompaniesController < ApplicationController
  include RestfulAction

  load_and_authorize_resource
  before_action :set_company, only: [:edit, :show, :update, :destroy]

  def index
    @offset = params[:offset] || 0
    @companies = Company.skip(@offset).limit(10)
    respond_to do |format|
      format.html
      format.json { render json: @companies.to_json(only:[:_slugs, :name, :gstno, :website])}
      format.csv { send_data @companies.to_csv }
    end
  end

  def new
    @company = Company.new
    @company.addresses.build
  end

  def create
    @company = Company.new(company_params)
    if @company.save
      flash[:success] = "Company created Succesfully"
      redirect_to companies_path
    else
      render 'new'
    end
  end

  def edit
    @company.addresses.present? ? @company.addresses : @company.addresses.build
  end

  def show
    @projects = @company.projects.group_by(&:is_active)
    respond_to do |format|
      format.html
      format.json{ render json: @projects.to_json}
    end
  end

  def update
    if @company.update(company_params)
      flash[:success] = "Company updated Succesfully"
      redirect_to companies_path
    else
      flash[:error] = "Company: #{@company.errors.full_messages.join(',')}"
      render 'edit'
    end
  end

  def destroy
    if @company.destroy
      flash[:notice] = "Company deleted Succesfully"
    else
      flash[:notice] = "Error in deleting Company"
    end
    redirect_to companies_path
  end

  private

  def company_params
    params.require(:company).permit(:name, :gstno, :logo, :website,
      contact_persons_attributes: [:id, :role, :name, :phone_no, :email, :_destroy],
      addresses_attributes: [:id, :type_of_address, :address, :city, :state, :landline_no, :pin_code, :_destroy])
  end

  def set_company
    @company = Company.find(params[:id])
  end
end
