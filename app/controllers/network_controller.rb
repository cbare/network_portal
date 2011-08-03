class NetworkController < ApplicationController

  def show_in_cytoscape_web
    render :template => "network/show.cytoscapeweb.html.erb", :layout => false
  end

  # def network
  #   @genes = Gene.find_all_by_name(params[:genes].split(' '))
  #   @options = session[:options] || Options.get_defaults
  # 
  #   respond_to do |format|
  # 
  #     format.html do
  #       @gene_names = @genes.map {|gene| gene.name}
  #       @edge_count = EdgeWeight.count_for_genes(@genes, @options.ensembles)
  #       logger.info("count genes = #{@genes.length}")
  #       logger.info("expanded gene list = #{@gene_names.join(', ')}")
  #       render :template => "network/show.cytoweb.html.erb"
  #     end
  # 
  #     format.xml do
  #       @network = Network.get_network_for_genes(@genes, @options.ensembles)
  #       logger.info "~~~~~~~~~~~~~~~~~~~~~~> rendering network to xml"
  #       # scale edge weights - hack 'cause I couldn't figure out cytoscape web's continuous mapper
  #       # @network.edges.each { |edge| edge.weight *= 16 }
  #       render :template => "network/show.xml.erb", :xml => @network, :content_type => "text/xml", :layout => false
  #     end
  #     
  #     format.json do
  #       @network = Network.get_network_for_genes(@genes, @options.ensembles)
  #       logger.info "~~~~~~~~~~~~~~~~~~~~~~> rendering network to json"
  #       @gene_id_map = {}
  #       i = 0
  #       @network.nodes.each do |gene|
  #         @gene_id_map[gene.id] = i
  #         i += 1
  #       end
  #       render :template => "network/show.json.erb", :content_type => "text/json", :layout => false
  #     end
  # 
  #   end
  # end

end
