package XBRL::Taxonomy;

use strict;
use warnings;
use Carp;
use XML::LibXML; 
use XML::LibXML::XPathContext; 
use XML::LibXML::NodeList; 
use XBRL::Element;
use XBRL::Label;
use Data::Dumper;
use Scalar::Util qw(reftype blessed); 


our $VERSION = '0.01';
our $agent_string = "Perl XBRL Library $VERSION";

use base qw(Class::Accessor);

XBRL::Taxonomy->mk_accessors( qw( elements pre def lab cal schemas main_schema ) );


sub new() {
	my ($class, $in_xml) = @_;
	my $self = { };
	bless $self, $class;

	if ($in_xml) {
		&parse($self, $in_xml);
	}

	return $self;
}

sub parse() {
	my ($self, $in_xml) = @_;
	
	my $main_schema_xpath = &make_xpath($self, $in_xml);

	my $ns_nodes = $main_schema_xpath->findnodes('//*[@targetNamespace]');

	my $ts = $ns_nodes->[0]->getAttribute('targetNamespace');
	my $orig_schema = XBRL::Schema->new( { namespace => $ts, file => $in_xml, xpath => $main_schema_xpath });	
	$self->{'schemas'}->{$ts} = $orig_schema;	
	$self->{'main_schema'} = $ts;
	
	my $other_schemas = $main_schema_xpath->findnodes("//*[local-name() = 'import']"); 
	
	for my $other (@$other_schemas) {
		my $ns = $other->getAttribute('namespace');
		my $location_url  = $other->getAttribute('schemaLocation');
		my $file_name = &get_file($self, $location_url);
		my $temp_xpath = &make_xpath($self, $file_name);
		my $scheme = XBRL::Schema->new( { namespace => $ns, file => $location_url, xpath => $temp_xpath });	
		$self->{'schemas'}->{$ns} = $scheme;	
		
		my $element_list = $temp_xpath->findnodes("//*[local-name() = 'element']");
		for my $el_xml (@$element_list) {
			#print $el_xml->toString() . "\n";	
			my $e = XBRL::Element->new($el_xml);
			if ($e->id()) { 
				$self->{'elements'}->{$e->id()} = $e;	
			}	
		}

		my $main_element_list = $main_schema_xpath->findnodes("//*[local-name() = 'element']");

		for my $element_xml (@{$main_element_list}) {
			my $e = XBRL::Element->new($element_xml);
			if ($e->id()) {
				$self->{'elements'}->{$e->id()} = $e;	
			}
		}



	}

#	#load the linkbases 
	my $lbs = $main_schema_xpath->findnodes("//*[local-name() = 'linkbaseRef']"  );

	for my $lb (@$lbs) {
		my $lb_file = $lb->getAttribute('xlink:href');	
		$lb_file = &get_file($self, $lb_file);	
		my $lb_xpath = &make_xpath($self, $lb_file);	
		my $pres_links = $lb_xpath->findnodes("//*[local-name() = 'presentationLink']");	
		my $def_links = $lb_xpath->findnodes("//*[local-name() = 'definitionLink']");	
		my $lab_links = $lb_xpath->findnodes("//*[local-name() = 'labelLink']");	
		my $cal_links = $lb_xpath->findnodes("//*[local-name() = 'calculationLink']");	
		
		if ($pres_links) {
			$self->{'pre'} = $lb_xpath;	
		}
		elsif ($def_links) {
			$self->{'def'} = $lb_xpath;	
		}
		elsif ($lab_links) {
			$self->{'lab'} = $lb_xpath;	
		}
		elsif ($cal_links) {
			$self->{'cal'} = $lb_xpath;	
		}
	
	}



	#Load the array of labels 

	my $label_arcs = $self->{'lab'}->findnodes("//*[local-name() =  'labelArc']");
	my $label_locs =  $self->{'lab'}->findnodes("//*[local-name() =  'loc']"); 
	my $label_labels =   $self->{'lab'}->findnodes("//*[local-name() =  'label']"); 

	my @label_array;

	for my $arc (@{$label_arcs}) {
		for my $loc (@{$label_locs}) {
			if ($arc->getAttribute('xlink:from') eq $loc->getAttribute('xlink:label')) {
				for my $label_node (@{$label_labels}) {
					if ( $arc->getAttribute('xlink:to') eq $label_node->getAttribute('xlink:label') ) {
							my $label = XBRL::Label->new();	
							my $href = $loc->getAttribute('xlink:href');	
							$href =~ m/\#([A-Za-z0-9_-].+)$/; 	
							$label->name($1);	
							$label->role($label_node->getAttribute('xlink:role'));
							$label->lang($label_node->getAttribute('xml:lang'));	
							$label->id($label_node->getAttribute('id'));
							$label->value( $label_node->textContent() );
							push(@label_array, $label);	
					}

				}
			}
		}

	}



#	my $labelLinkNodes = $self->{'lab'}->findnodes("//*[local-name() = 'labelLink']");
#
#	my @label_array = ();
#
#	for my $labelLink (@{$labelLinkNodes}) {
#		my $label =  XBRL::Label->new($labelLink);	
#		push(@label_array,$label);
#	}
#
	$self->{'labels'} =\@label_array; 


}

sub get_elementbyid() {
	my ($self, $e_id) = @_;

	return( $self->{'elements'}->{$e_id} );
}



sub make_xpath() {
	#take a file path and return an xpath context
	my ($self, $in_file) = @_;
	
	if (! -e $in_file) {
		my $extended_file = &get_file($self, $in_file);	
		if ( ! -e $extended_file) {	
			croak "$in_file doesn't exist\n";
		}	
		else {
			$in_file = $extended_file;	
		}
	
	}
	
	my $ns = &extract_namespaces($self, $in_file); 

	my $xml_doc =XML::LibXML->load_xml( location => $in_file); 

	my $xml_xpath = XML::LibXML::XPathContext->new($xml_doc);
	
	for (keys %{$ns}) {
		$xml_xpath->registerNs($_, $ns->{$_});
	}
	return $xml_xpath;
}

sub extract_namespaces() {
	#take an xml string and return an hash ref with name and 
	#urls for all the namespaces 
	my ($self, $xml) = @_; 
	my %out_hash = ();
	my $parser = XML::LibXML->new();
	my $doc = $parser->load_xml( location => $xml );

	my $root = $doc->documentElement();

	my @ns = $root->getNamespaces();
	for (@ns) {
		my $localname = $_->getLocalName();
		if (!$localname) {
			$out_hash{'default'} = $_->getData();
		}
		else {	
			$out_hash{$localname} = $_->getData();	
		}	
	}
	return \%out_hash;
}

sub get_file() {
	#manage the whole file thang.
	my ($self, $in_file) = @_;
	
	if ($in_file =~ m/^http\:\/\//) {
		$in_file =~ m/^http\:\/\/[a-zA-Z0-9\/].+\/(.*)$/;
		my $local_file = $1;
		if ( -e $local_file) {
			return $local_file;
		}
		else {
			my $ua = LWP::UserAgent->new();
			$ua->agent($agent_string);
			my $response = $ua->get($in_file);
			if ($response->is_success) {
				my $fh;	
				open($fh, ">$local_file") or croak "can't open $local_file because: $! \n";
				print $fh $response->content;	
				close $fh;	
				return $local_file;	
			}	

		}

	}

	if ( ! -e $in_file) {
		my $test_path;	
		if ($self->{'base'}) {
			$test_path = $self->{'base'} . $in_file;
			if ( -e $test_path) {
				return $test_path;
			}
			else {
				croak "Can't find $test_path\n";
			}
		}
	}
	else {
		return $in_file;
	}
}


sub get_sections() {
	my ($self) = @_;
	my @out_array = ();	
	my $ms = $self->{'main_schema'}; 
	my $search_schema = $self->{'schemas'}->{$ms};
	my $search_xpath = $search_schema->xpath();
	my $sections = $search_xpath->findnodes('//link:roleType');
	
	for my $section (@$sections) {
		my $uri = $section->getAttribute('roleURI');	
		my $def = $section->findnodes('link:definition');
		$def =~ m/(^\d+\d)/;	
		my $order = $1;	
		push(@out_array, { def => $def, uri => $uri, order => $order }); 
	}
	
	my @sorted_array = sort { $a->{'order'} <=> $b->{'order'} } @out_array;	
	
	return \@sorted_array;
}


sub debug_subsects() {
	my ($self, $section_uri) = @_;
	my $p_link = $self->{'pre'}->findnodes("//*[local-name() = 'presentationLink'][\@xlink:role = '" . $section_uri . "' ]"); 
	if ($p_link) {	
		my $child_nodes = $p_link->[0]->childNodes();

		for my $node ( $child_nodes->get_nodelist() ) {
			if ($node->nodeName() =~ m/loc/) {	
				print "Locator \n";	
				my $element_uri = $node->getAttribute('xlink:href');	
				print "\tHref: " . $element_uri . "\n";	
				print "\tLabel: " . $node->getAttribute('xlink:label') . "\n";	
				
				$element_uri =~ m/\#([A-Za-z0-9_-].+)$/; 	
				my $element_id = $1;
				my $element = &get_elementbyid($self, $element_id);	
				print "\tType: " . $element->type() . "\n";
				print "\tSubGroup: " . $element->subGroup() . "\n";
			}	
			elsif ($node->nodeName() =~ m/presentationArc/) {
				print "PresentationArc \n";
				print "\tFrom: " . $node->getAttribute('xlink:from') . "\n";	
				print "\tTo: " . $node->getAttribute('xlink:to') . "\n";	
				print "\tOrder: " . $node->getAttribute('order') . "\n";	
			}
		}
	}
}


sub in_def() {
	#take a section uri and check if there is a 
	#section for it in the definition link base
	#return nodelist of def  if true,  undef if not
	my ($self, $sec_uri) = @_; 

	my $d_link = $self->{'def'}->findnodes("//*[local-name() = 'definitionLink'][\@xlink:role = '" . $sec_uri . "' ]"); 

	if ($d_link) {
		return $d_link;
	}
	else {
		return undef;
	}

}

sub get_pre_elems2() {
	my ($self, $sec_uri) = @_;
	my @out_array = ();
	my $p_link = $self->{'pre'}->findnodes("//*[local-name() = 'presentationLink'][\@xlink:role = '" . $sec_uri . "' ]"); 

	if ($p_link) {	

		my $loc_list = $p_link->[0]->getChildrenByLocalName('loc');
		my $arc_list = $p_link->[0]->getChildrenByLocalName('presentationArc');	
		
		
		my %subsections = (); 
		my @subsec_array = ();
		for (@{$loc_list}) {
			my $element_uri = $_->getAttribute('xlink:href');
			$subsections{$element_uri}++;
		}
				
		for my $loc (@{$loc_list}) {
			my $href = $loc->getAttribute('xlink:href');
			if (($subsections{$href}) && ($subsections{$href} > 0)) {
				push(@subsec_array, $href);
				delete $subsections{$href};
			}
		}
		
		for my $section (@subsec_array) {
			my @section_array = ();	
			#print "Working on SubSection: $section \n";	
			#iterate through all the locs and find ones that match the section names
			for my $loc (@$loc_list) {
				my $xlink = $loc->getAttribute('xlink:href');
				if ($xlink eq $section) {
					my $loc_label = $loc->getAttribute('xlink:label');	
					#print "\t" . $loc_label . "\n";
						for my $arc (@{$arc_list}) {
							my $arc_from = $arc->getAttribute('xlink:from');	
							my $arc_to = $arc->getAttribute('xlink:to');	
							
							if ($arc_from eq $loc_label ) { 	
								my $order = $arc->getAttribute('order');	
								#print "\t\t" . $order . "\n";
								for my $el_loc (@{$loc_list}) {
									my $label = $el_loc->getAttribute('xlink:label');
									if ($arc_to eq $label) {
										my $el_link = $el_loc->getAttribute('xlink:href');
										$el_link =~ m/\#([A-Za-z0-9_-].+)$/; 		
										my $el_id = $1;	
										#$el_id =~ s/\_/\:/;	
										#print "\t\t $el_id \n";	
										push(@section_array, { section => $section,
																					order => $order,
																					element_id => $el_id } );
									}
								}
							}	
						}
				}
			}

		
		my @ordered_array = sort { $a->{'order'} <=> $b->{'order'} } @section_array;	
			for my $item (@ordered_array) {
				#$item->{'element_id'} =~ s/\:/\_/g;	
				#print "\t" . $item->{'order'} . "\t" . $item->{'element_id'} . "\n";
				my $e = $self->get_elementbyid($item->{'element_id'});
				if (! $e ) {
					croak "Couldn't find element for: " . $item->{'element_id'} . "\n";
				}
				push(@out_array, $self->get_elementbyid($item->{'element_id'}));  
			}
		}		

	}
	return \@out_array;
}
	
#sub get_pre_elems() {
#	my ($self, $sec_uri) = @_;
#	my @out_array = ();
#	my $p_link = $self->{'pre'}->findnodes("//*[local-name() = 'presentationLink'][\@xlink:role = '" . $sec_uri . "' ]"); 
#
#	if ($p_link) {	
#
#		my $p_arcs = $p_link->[0]->getChildrenByTagName('presentationArc');
#		#sort the results
#		#my @sorted_arcs = sort { $a->getAttribute('order') <=> $b->getAttribute('order')  } @$p_arcs;
#
#
#		#for my $arc (@sorted_arcs) {
#		for my $arc (@$p_arcs) {
#			my $dest = $arc->getAttribute('xlink:to');
#			#my @loc_links = $p_link->[0]->getChildrenByTagName('loc');
#			my @loc_links = $p_link->[0]->findnodes("//*[local-name() = 'loc']"); 
#	
#			#complete name issue 
#			for my $locator(@loc_links) {
#				my $label = $locator->getAttribute('xlink:label');
#				if ($dest eq $label) {
#					my $item_link = $locator->getAttribute('xlink:href');
#					$item_link =~ m/\#([A-Za-z0-9_-].+)$/; 	
#					my $element_id = $1;
#					push(@out_array, $self->get_elementbyid($element_id));  
#				}
#			}
#		}
#	}
#	return \@out_array;
#}

#sub get_label() {
#	#takes an element and finds the correct label for it
#	#via xpath search of the label linkbase
#	my ($self, $search_id) = @_;
#	my $lang = 'en-US';
#
#	if (!$search_id) {
#		croak "set_label called without an xbrl element id\n";
#	}
#
#	my $loc_nodes = $self->{'lab'}->findnodes("//*[local-name() = 'loc']");
#	my $label_nodes = $self->{'lab'}->findnodes("//*[local-name() = 'label'][\@xlink:role = 'http://www.xbrl.org/2003/role/label'][\@xml:lang = 'en-US'] ");	
#	my $label_arc_nodes = $self->{'lab'}->findnodes("//*[local-name() = 'labelArc']");	
#
#	if (!$label_nodes) {
#		croak "no loc nodes for: " . $search_id->id() . "\n";
#	}
#
#	my $arc_locator;
#	for my $loc (@{$loc_nodes}) {
#		my $href = $loc->getAttribute('xlink:href');	
#		my $id = $href;
#		$id =~ m/\#([A-Za-z0-9_-].+)$/; 	 
#		my $arc_id = $1;	
#
#		if ($arc_id eq $search_id) {
#			$arc_locator = $loc->getAttribute('xlink:label');
#		}
#	}
#
#	#if (!$arc_locator) { croak "no arc locator for " . $search_id->id() . "\n"; }
#	if (!$arc_locator) { return undef; }
#	
#	my $label_loc;
#	for my $label_arc (@{$label_arc_nodes}) {
#		my $from = $label_arc->getAttribute('xlink:from');	
#		if ($from eq $arc_locator) {
#			$label_loc = $label_arc->getAttribute('xlink:to');
#		}
#	}
#
#
#	#if (!$label_loc) {croak "no label locator for " . $search_id->id() . "\n"; } 
#	if (!$label_loc) {return undef; } 
#
#	my $label_text;
#	for my $label_node (@{$label_nodes}) {
#		my $link = $label_node->getAttribute('xlink:label');
#		if ($link eq $label_loc) {
#			$label_text = $label_node->textContent();
#		}
#	}
#	if ($label_text) {
#		return $label_text;
#	}
#	else {
#		return $search_id;
#	}
#}


sub get_label() {
	my ($self, $search_id, $role) = @_;

	if (!$role) {
		$role = 'http://www.xbrl.org/2003/role/label';
	}

	for my $label (@{$self->{'labels'}}) {
		if (($label->name() eq $search_id) && ($label->role() eq $role)) {
			return $label->value();
		}
	}
	
	$role = 'http://www.xbrl.org/2003/role/label';
	
	for my $label (@{$self->{'labels'}}) {
		if (($label->name() eq $search_id) && ($label->role() eq $role)) {
			return $label->value();
		}
	}


}




1;

