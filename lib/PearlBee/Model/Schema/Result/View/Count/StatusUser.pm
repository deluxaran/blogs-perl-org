package PearlBee::Model::Schema::Result::View::Count::StatusUser;

# This view is used for counting all stauts

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('user');
__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(
    q[
      SELECT
      	SUM( status = 'inactive' ) AS inactive,
      	SUM( status = 'active') AS active,
      	SUM( status = 'suspended' ) AS suspended,
        SUM( status = 'pending' ) AS pending,
      	COUNT(*) AS total
      FROM
      	user
    ]
);

__PACKAGE__->add_columns(
  "inactive",
  { data_type => "integer", is_nullable => 0 },
  "active",
  { data_type => "integer", is_nullable => 0 },
  "suspended",
  { data_type => "integer", is_nullable => 0 },
  "pending",
  { data_type => "integer", is_nullable => 0 },
  "total",
  { data_type => "integer", is_nullable => 0 },
);

sub get_all_status_counts {
  my $self = shift;

  return ( $self->total, $self->active, $self->inactive, $self->suspended, $self->pending );
}

sub get_status_count {
  my ($self, $status) = @_;

  return ( $status eq 'active' ) ? $self->active : ( $status eq 'inactive' ) ? $self->inactive : ( $status eq 'suspended' ) ? $self->suspended : $self->pending;
}

1;
