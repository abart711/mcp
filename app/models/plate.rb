class Plate < ActiveRecord::Base
	validates :license, uniqueness: true

	has_many :usersplates
  	has_many :users, :through => :usersplates
	has_many :tickets

	def scrape	
		plate = self
		agent = Mechanize.new

	    page = agent.get('https://step1.caledoncard.com/citations/milwaukee.html')
	    mcp_form = page.form('CITATION')
	    mcp_form.LIC = plate.license
	    page = agent.submit(mcp_form)
	    table = page.search('#Processing table table table tr')
	    table_rows = table[1..-3]
		    
	    #Create the parent array that we will place each row into.
	    @row_array = Array.new
	    
	    #Loop through table rows.
	    table_rows.each_with_index do |tr, key|
	      row = tr.children[1..-2].text
	      
	      #Create an array of the cell values in this row.
	      citation_array = row.split(' ')
	      
	      #Create a new hash that we will store the cell rows in.
	      citation_hash = Hash.new

	      #Loop through the cells and place them in the hash.
	      citation_array.each_with_index do |cell, key|
	        #citation_hash[key] = cell
	        if key == 0
	          citation_hash['citation_number'] = cell
	        elsif key == 1
	          citation_hash['license'] = cell
	        elsif key == 2
	          date = Date.strptime(cell, "%m/%d/%y")
	          citation_hash['date'] = date.strftime("%Y-%m-%d")
	        elsif key == 3
	          citation_hash['price'] = cell
	        elsif key == 4
	          citation_hash['fee'] = cell
	        end
	      end

	      #Place the hash into the parent array.
	      @row_array[key] = citation_hash
	    end
	    
	    #Set all of the tickets for this plate as paid.
	    plate.tickets.update_all(:paid => true)
	    
	    #Insert/updated each of these tickets into the database.
	    @row_array.each do |value|
	      #Check if this ticket already exists. If so, update it.
	      ticket = Ticket.where('citation_number = ?', value['citation_number']).first
	      if ticket
	        ticket.price = value['price']
	        ticket.fee = value['fee']
	        ticket.paid = false
	        ticket.save
	      else
	        #If this ticket does not exist, add it to the database.        
	        @ticket = Ticket.create(
	          plate_id: plate.id,
	          citation_number: value['citation_number'],
	          date: value['date'],
	          price: value['price'],
	          paid: false,
	          price_increase: false,
	          fee: value['fee']
	        )
	      TicketMailer.new_ticket(@ticket).deliver
	      end
	    end

	    plate.updated_at = Time.now
	    plate.save
	end
end
