require 'spec_helper'

describe User do  


  it { should have_fields(:email, :encrypted_password, :role, :uid, :provider, :status) }
  it { should have_field(:status).of_type(String).with_default_value_of(STATUS[0]) }
  it { should embed_one :public_profile }
  it { should embed_one :private_profile }
  it { should accept_nested_attributes_for(:public_profile) }
  it { should accept_nested_attributes_for(:private_profile) }
  it { should validate_presence_of(:role) }
  it { should validate_presence_of(:email) }

  
  it "should have employer as default role when created" do
    user = FactoryGirl.build(:user)
    expect(user.role).to eq("Employee")
    expect(user.role?("Employee")).to eq(true)
  end 
  
  it "intern should not eligible for leave" do
    user = FactoryGirl.build(:user, role: 'Intern', email: 'intern@company.com')
    user.save
    expect(user.eligible_for_leave?).to eq(false) 
  end

  it "nil date of joining employee should not eligible for leave" do
    user = FactoryGirl.build(:user, email: 'employee@company.com')
    user.save
    expect(user.eligible_for_leave?).to eq(false) 
  end 
  
  it "valid employee should be eligible for leave" do
    user = FactoryGirl.build(:user, private_profile: FactoryGirl.build(:private_profile, date_of_joining: Date.new(Date.today.year, Date.today.month, 01).prev_month))
    user.save!
     
    expect(user.eligible_for_leave?).to eq(true) 
  end 

  it 'should assign website sequence number auto incremented for new user' do
    user1 = FactoryGirl.create(:user, email: "test2@joshsoftware.com")
    expect(user1.website_sequence_number).to eq(1)
    user = FactoryGirl.create(:user, email: 'test123@joshsoftware.com')
    expect(user.reload.website_sequence_number).to eq(2)
  end

  it "should reset yearly leave" do
    user = FactoryGirl.build(:user, private_profile: FactoryGirl.build(:private_profile, date_of_joining: Date.new(Date.today.year - 1, Date.today.month, 19).prev_month))
    user.save
    user.reload
    user.set_leave_details_per_year
    user.reload
    expect(user.employee_detail.available_leaves).to eq(PER_MONTH_LEAVE*12)
  end

  context "sent mail for approval" do

    ##### check date of joining in case of specs fail
    before (:each) do
      @user = FactoryGirl.create(:user, private_profile: FactoryGirl.build(:private_profile, date_of_joining: Date.new(Date.today.year, Date.today.month, 19)))
      @user.save
    end

    it "should send email if HR and admin roles are present" do
      hr_user = FactoryGirl.create(:user, role: "HR", email: "hr@joshsoftware.com", password: "josh123", private_profile: FactoryGirl.build(:private_profile, date_of_joining: Date.new(Date.today.year, Date.today.month, 19) - 10.month))
      admin_user = FactoryGirl.create(:user, role: "Admin", email: "admin@joshsoftware.com", password: "josh123", private_profile: FactoryGirl.build(:private_profile, date_of_joining: Date.new(Date.today.year, Date.today.month, 19) - 10.month))
      leave_application = FactoryGirl.create(:leave_application, user_id: @user.id)
      expect{@user.sent_mail_for_approval(leave_application)}.not_to raise_error
    end

    it "should send email if HR role is absent" do
      admin_user = FactoryGirl.create(:user, role: "Admin", email: "admin@joshsoftware.com", password: "josh123", private_profile: FactoryGirl.build(:private_profile, date_of_joining: Date.new(Date.today.year, Date.today.month, 19) - 10.month))
      leave_application = FactoryGirl.create(:leave_application, user_id: @user.id)
      expect(User.where(role: 'HR')).to eq([])
      expect{@user.sent_mail_for_approval(leave_application)}.not_to raise_error
    end
    
    it "should send email if admin role is absent" do
      hr_user = FactoryGirl.create(:user, role: "HR", email: "hr@joshsoftware.com", password: "josh123", private_profile: FactoryGirl.build(:private_profile, date_of_joining: Date.new(Date.today.year, Date.today.month, 19) - 10.month))
      leave_application = FactoryGirl.create(:leave_application, user_id: @user.id)
      expect(User.where(role: 'Admin')).to eq([])
      expect{@user.sent_mail_for_approval(leave_application)}.not_to raise_error
    end

    it "should send email if hr and admin roles are absent" do
      leave_application = FactoryGirl.create(:leave_application, user_id: @user.id)
      expect(User.where(role: 'Admin')).to eq([])
      expect(User.where(role: 'HR')).to eq([])
      expect{@user.sent_mail_for_approval(leave_application)}.not_to raise_error
    end
  end

  context 'Timesheet' do
    let!(:user) { FactoryGirl.create(:user) }
    let!(:project) { FactoryGirl.create(:project) }

    it 'Should give the project report' do
      UserProject.create(user_id: user.id, project_id: project.id, start_date: Date.today - 2)
      projects = user.projects
      expect(projects.present?).to eq(true)
    end

    it 'Should give worked on project form from date and to date' do
      UserProject.create(user_id: user.id, project_id: project.id, start_date: Date.today - 3, end_date: nil)
      TimeSheet.create(user_id: user.id, project_id: project.id, date: Date.today - 1, from_time: '9:00', to_time: '10:00', description: 'Woked on test cases')
      projects = user.worked_on_projects(Date.today - 2, Date.today)
      expect(projects.present?).to eq(true)
    end
  end

  context 'Add or remove project' do
    let!(:user) { FactoryGirl.create(:user) }
    let!(:project) { FactoryGirl.build(:project) }

    it 'Should add project' do
      project_ids = []
      project_ids << ""
      project_ids << project.id
      params = { user: { project_ids: project_ids } }
      user.add_or_remove_projects(params)
      user_project = UserProject.find_by(user_id: user.id, project_id: project.id)
      expect(user_project.start_date).to eq(Date.today)
    end

    describe 'Remove project' do
      it 'Project count grater than tow' do
        project_ids = []
        first_project = FactoryGirl.create(:project, name: 'test1')
        second_project = FactoryGirl.create(:project, name: 'test2')
        UserProject.create(user_id: user.id, project_id: first_project.id, start_date: DateTime.now - 1, end_date: nil)
        UserProject.create(user_id: user.id, project_id: second_project.id, start_date: DateTime.now - 1, end_date: nil)
        user_project = UserProject.create(user_id: user.id, project_id: project.id, start_date: DateTime.now - 1, end_date: nil)
        project_ids << ""
        project_ids << first_project.id
        project_ids << second_project.id
        params = { user: { project_ids: project_ids } }
        user.add_or_remove_projects(params)
        expect(user_project.reload.end_date).to eq(Date.today)
      end

      it 'Project count is one' do
        project_ids = []
        user_project = UserProject.create(user_id: user.id, project_id: project.id, start_date: DateTime.now - 1, end_date: nil)
        project_ids << ""
        params = { user: { project_ids: project_ids } }
        user.add_or_remove_projects(params)
        expect(user_project.reload.end_date).to eq(Date.today)
      end

      it 'Add project : should return false because project id nil' do
        project_ids = []
        project_ids << nil
        return_value = user.add_projects(project_ids)
        expect(return_value).to eq(false)
      end

      it 'Remove project : should return false because project id nil' do
        project_ids = []
        project_ids << nil
        return_value = user.remove_projects(project_ids)
        expect(return_value).to eq(false)
      end
    end
  end
  
  context 'Get managers emails' do
    let!(:user) { FactoryGirl.create(:user) }

    it 'Should give the managers emails of particular user' do
      project = FactoryGirl.create(:project)
      manager_one = FactoryGirl.create(:user, role: 'Manager')
      manager_two = FactoryGirl.create(:user, role: 'Manager')
      UserProject.create(user_id: user.id, project_id: project.id, start_date: Date.today - 2, end_date: nil)
      project.managers << manager_one
      project.managers << manager_two
      managers_emails = user.get_managers_emails
      expect(managers_emails.count).to eq(2)
      expect(managers_emails[0]).to eq(managers_emails[0])
      expect(managers_emails[1]).to eq(managers_emails[1])
    end

    it 'Should skip the email if already added' do
      project_one = FactoryGirl.create(:project)
      project_two = FactoryGirl.create(:project, name: 'test')
      UserProject.create(user_id: user.id, project_id: project_one.id, start_date: Date.today - 2, end_date: nil)
      UserProject.create(user_id: user.id, project_id: project_two.id, start_date: Date.today - 2, end_date: nil)
      manager = FactoryGirl.create(:user, role: 'Manager')
      project_one.managers << manager
      project_two.managers << manager
      managers_emails = user.get_managers_emails
      expect(managers_emails.count).to eq(1)
      expect(managers_emails[0]).to eq(managers_emails[0])
    end

    it 'Should not give the managers emails if manager is not assigned to project' do
      project = FactoryGirl.create(:project)
      UserProject.create(user_id: user.id, project_id: project.id, start_date: Date.today - 2, end_date: nil)
      managers_emails = user.get_managers_emails
      expect(managers_emails.count).to eq(0)
    end

    context 'Get user project from user' do
      let!(:user) { FactoryGirl.create(:user, email: 'user1@joshsoftware.com') }
      let!(:project) { FactoryGirl.create(:project) }

      it "Should give the record if user's project start date is less than from date and end date is nil" do
        UserProject.create(user_id: user.id, project_id: project.id, start_date: '01/08/2018'.to_date, end_date: nil)
        from_date = '01/09/2018'.to_date
        to_date = '20/09/2018'.to_date
        user_projects = user.get_user_projects_from_user(project.id, from_date, to_date)
        expect(user_projects.count).to eq(1)
        expect(user_projects[0].start_date.to_s).to eq('01/08/2018')
        expect(user_projects[0].end_date).to eq(nil)
      end

      it "Should give the record if user's project start date is greater than from date and end date is nil" do
        UserProject.create(user_id: user.id, project_id: project.id, start_date: '06/09/2018'.to_date, end_date: nil)
        from_date = '01/09/2018'.to_date
        to_date = '20/09/2018'.to_date
        user_projects = user.get_user_projects_from_user(project.id, from_date, to_date)
        expect(user_projects.count).to eq(1)
        expect(user_projects[0].start_date.to_s).to eq('06/09/2018')
        expect(user_projects[0].end_date).to eq(nil)
      end

      it "Should give the record if user's project start date is greater than from date and end date is less than to date" do
        UserProject.create(user_id: user.id, project_id: project.id, start_date: '05/09/2018'.to_date, end_date: '15/09/2018'.to_date)
        from_date = '01/09/2018'.to_date
        to_date = '20/09/2018'.to_date
        user_projects = user.get_user_projects_from_user(project.id, from_date, to_date)
        expect(user_projects.count).to eq(1)
        expect(user_projects[0].start_date.to_s).to eq('05/09/2018')
        expect(user_projects[0].end_date.to_s).to eq('15/09/2018')
      end

      it "Should give the record if user's project start date is greater than from date and end date is greater than to date" do
        UserProject.create(user_id: user.id, project_id: project.id, start_date: '08/09/2018'.to_date, end_date: '23/09/2018'.to_date)
        from_date = '01/09/2018'.to_date
        to_date = '20/09/2018'.to_date
        user_projects = user.get_user_projects_from_user(project.id, from_date, to_date)
        expect(user_projects.count).to eq(1)
        expect(user_projects[0].start_date.to_s).to eq('08/09/2018')
        expect(user_projects[0].end_date.to_s).to eq('23/09/2018')
      end

      it "Should give the record if user's project start date less than from date and end date less than to date" do
        UserProject.create(user_id: user.id, project_id: project.id, start_date: '05/08/2018'.to_date, end_date: '10/09/2018'.to_date)
        from_date = '01/09/2018'.to_date
        to_date = '20/09/2018'.to_date
        user_projects = user.get_user_projects_from_user(project.id, from_date, to_date)
        expect(user_projects.count).to eq(1)
        expect(user_projects[0].start_date.to_s).to eq('05/08/2018')
        expect(user_projects[0].end_date.to_s).to eq('10/09/2018')
      end

      it "Should give the record if user's project start date is less than from date and end date is greater than to date" do
        UserProject.create(user_id: user.id, project_id: project.id, start_date: '01/08/2018'.to_date, end_date: '10/10/2018'.to_date)
        from_date = '01/09/2018'.to_date
        to_date = '20/09/2018'.to_date
        user_projects = user.get_user_projects_from_user(project.id, from_date, to_date)
        expect(user_projects.count).to eq(1)
        expect(user_projects[0].start_date.to_s).to eq('01/08/2018')
        expect(user_projects[0].end_date.to_s).to eq('10/10/2018')
      end
  
      it "Should give the record if user remove from project and added to same project in searching period" do
        UserProject.create(user_id: user.id, project_id: project.id, start_date: '01/08/2018'.to_date, end_date: '10/10/2018'.to_date)
        UserProject.create(user_id: user.id, project_id: project.id, start_date: '11/09/2018'.to_date, end_date: nil)
        from_date = '01/09/2018'.to_date
        to_date = '20/09/2018'.to_date
        user_projects = user.get_user_projects_from_user(project.id, from_date, to_date)
        expect(user_projects.count).to eq(2)
        expect(user_projects[0].start_date.to_s).to eq('01/08/2018')
        expect(user_projects[0].end_date.to_s).to eq('10/10/2018')
        expect(user_projects[1].start_date.to_s).to eq('11/09/2018')
      end
  
      it "Should not give the record because user's project start date and end date is not between from date and to date" do
        UserProject.create(user_id: user.id, project_id: project.id, start_date: '01/08/2018'.to_date, end_date: '25/08/2018'.to_date)
        from_date = '01/09/2018'.to_date
        to_date = '20/09/2018'.to_date
        user_projects = user.get_user_projects_from_user(project.id, from_date, to_date)
        expect(user_projects.count).to eq(0)
        expect(user_projects.present?).to eq(false)
      end

      it "Should not give the record because user's project start date and end date is not between from date and to date" do
        UserProject.create(user_id: user.id, project_id: project.id, start_date: '25/09/2018'.to_date, end_date: '30/09/2018')
        from_date = '01/09/2018'.to_date
        to_date = '20/09/2018'.to_date
        user_projects = user.get_user_projects_from_user(project.id, from_date, to_date)
        expect(user_projects.count).to eq(0)
        expect(user_projects.present?).to eq(false)
      end
    end
  end
  context 'Employee Auto Id generation' do
    let!(:user) { FactoryGirl.create(:user,public_profile: FactoryGirl.build(:public_profile)) }
    let(:internuser) { FactoryGirl.create(:user, role: 'Intern', email: 'intern@joshsoftware.com',employee_detail: FactoryGirl.build(:employee_detail))}
    it "should generate new Employee ID if employee is new" do      
      user = FactoryGirl.create(:user, public_profile: FactoryGirl.build(:public_profile))
      expect(user.employee_detail.employee_id.to_i).to eq(2)
    end

    it "should not generate ID if employee is exist" do
      user = FactoryGirl.create(:user, public_profile: FactoryGirl.build(:public_profile))
      expect(user.employee_detail.employee_id).to eq(user.employee_detail.employee_id)
    end

    it "should not generate ID if user role is Intern" do
      user = FactoryGirl.create(:user, role: 'Intern', email: 'intern@joshsoftware.com')
      expect(user.employee_detail).to eq(nil)
    end

    it "should generate id when user role is changed Intern to Employee" do
      internuser.update_attributes(role: "Employee")
      expect(internuser.employee_detail.employee_id.to_i).to eq(2)
    end

    it "should not override other details when user role is changed intern to employee" do
      internuser.update_attributes(role: "Employee")
      expect(internuser.dob_day).to eq(internuser.dob_day)
      expect(internuser.dob_month).to eq(internuser.dob_month)
      expect(internuser.doj_day).to eq(internuser.doj_day)
      expect(internuser.doj_month).to eq(internuser.doj_month)
      expect(internuser.email).to eq(internuser.email)
      expect(internuser.status).to eq(internuser.status)
      expect(internuser.employee_detail.employee_id.to_i).to eq(2)
      expect(internuser.employee_detail.date_of_relieving).to eq(internuser.employee_detail.date_of_relieving)
      expect(internuser.employee_detail.available_leaves).to eq(internuser.employee_detail.available_leaves)
    end
  end
end
