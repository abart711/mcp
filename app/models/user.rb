class User < ActiveRecord::Base
	has_secure_password
	validates :name, :email, :presence => true
	attr_accessible :name, :email, :password, :password_confirmation
	before_save { |user| user.email = user.email.downcase }
  	before_save :create_remember_token
	
	has_many :authorizations
	has_and_belongs_to_many :plates

	private

	def create_remember_token
		self.remember_token = SecureRandom.urlsafe_base64
	end
end