package Geo::CEP;
# ABSTRACT: Resolve Brazilian city data for a given CEP

=for test_synopsis
my ($VAR1);

=head1 SYNOPSIS

    use Data::Dumper;
    use Geo::CEP;

    my $gc = new Geo::CEP;
    print Dumper $gc->find("12420-010");

Produz:

    $VAR1 = {
              'state_long' => "S\x{e3}o Paulo",
              'city' => 'Pindamonhangaba',
              'lat' => '-22.9166667',
              'lon' => '-45.4666667',
              'ddd' => '12',
              'state' => 'SP'
            };

=head1 DESCRIPTION

Obtém os dados como: nome da cidade, do estado, número DDD e latitude/longitude (da cidade) para um número CEP (Código de Endereçamento Postal) brasileiro.

Diferentemente do L<WWW::Correios::CEP>, consulta os dados armazenados localmente.
Por um lado, isso faz L<Geo::CEP> ser extremamente rápido (5 mil consultas por segundo); por outro, somente as informações à nível de cidade são retornadas.

=cut

use strict;
use utf8;
use warnings qw(all);

use integer;

use Carp qw(carp confess);
use Fcntl qw(SEEK_END SEEK_SET O_RDONLY);
use File::ShareDir qw(dist_file);
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use Text::CSV;

# VERSION

has csv     => (is => 'ro', isa => InstanceOf['Text::CSV'], default => sub { Text::CSV->new }, lazy => 1);
has data    => (is => 'rw', isa => FileHandle);
has index   => (is => 'rw', isa => FileHandle);
has length  => (is => 'rw', isa => Int, default => sub { 0 });
has offset  => (is => 'rw', isa => Int, default => sub { 0 });

=attr states

Mapeamento de código de estado para o nome do estado (C<AC =E<gt> 'Acre'>).

=cut

has states  => (
    is      => 'ro',
    isa     => HashRef[Str],
    default => sub {{
        AC  => 'Acre',
        AL  => 'Alagoas',
        AM  => 'Amazonas',
        AP  => 'Amapá',
        BA  => 'Bahia',
        CE  => 'Ceará',
        DF  => 'Distrito Federal',
        ES  => 'Espírito Santo',
        GO  => 'Goiás',
        MA  => 'Maranhão',
        MG  => 'Minas Gerais',
        MS  => 'Mato Grosso do Sul',
        MT  => 'Mato Grosso',
        PA  => 'Pará',
        PB  => 'Paraíba',
        PE  => 'Pernambuco',
        PI  => 'Piauí',
        PR  => 'Paraná',
        RJ  => 'Rio de Janeiro',
        RN  => 'Rio Grande do Norte',
        RO  => 'Rondônia',
        RR  => 'Roraima',
        RS  => 'Rio Grande do Sul',
        SC  => 'Santa Catarina',
        SE  => 'Sergipe',
        SP  => 'São Paulo',
        TO  => 'Tocantins',
    }}
);

=attr idx_len

Tamanho do registro de índice.

=cut

has idx_len => (is => 'ro', isa => Int, default => sub { length(pack('N*', 1 .. 2)) });

=for Pod::Coverage
BUILD
DEMOLISH
=cut

sub BUILD {
    my ($self) = @_;

    $self->csv->column_names([qw(cep_initial cep_final state city ddd lat lon)]);

    ## no critic (RequireBriefOpen)
    open(my $data, '<:encoding(latin1)', dist_file('Geo-CEP', 'cep.csv'))
        or return confess "Error opening CSV: $!";
    $self->data($data);

    sysopen(my $index, dist_file('Geo-CEP', 'cep.idx'), O_RDONLY)
        or return confess "Error opening index: $!";
    $self->index($index);

    my $size = sysseek($index, 0, SEEK_END)
        or return confess "Can't tell(): $!";

    return confess 'Inconsistent index size' if not $size or ($size % $self->idx_len);
    $self->length($size / $self->idx_len);

    return;
}

sub DEMOLISH {
    my ($self) = @_;

    close $self->data;
    close $self->index;

    return;
}

=method get_idx($n)

Retorna a posição no arquivo CSV; uso interno.

=cut

sub get_idx {
    my ($self, $n) = @_;

    my $buf = '';
    sysseek($self->index, $n * $self->idx_len, SEEK_SET)
        or return confess "Can't seek(): $!";

    sysread($self->index, $buf, $self->idx_len)
        or return confess "Can't read(): $!";
    my ($cep, $offset) = unpack('N*', $buf);

    $self->offset($offset);

    return $cep;
}

=method bsearch($hi, $val)

Efetua a busca binária (implementação não-recursiva); uso interno.

=cut

sub bsearch {
    my ($self, $hi, $val) = @_;
    my ($lo, $cep, $mid) = qw(0 0 0);

    return 0 if
        ($self->get_idx($lo) > $val) or
        ($self->get_idx($hi) < $val);

    while ($lo <= $hi) {
        $mid = int(($lo + $hi) / 2);
        $cep = $self->get_idx($mid);
        if ($val < $cep) {
            $hi = $mid - 1;
        } elsif ($val > $cep) {
            $lo = $mid + 1;
        } else {
            last;
        }
    }

    return ($cep > $val)
        ? $self->get_idx($mid - 1)
        : $cep;
}

=method find($cep)

Busca por C<$cep> (no formato I<12345678> ou I<"12345-678">) e retorna I<HashRef> com:

=for :list
* I<state>: sigla da Unidade Federativa (SP, RJ, MG);
* I<state_long>: nome da Unidade Federativa (São Paulo, Rio de Janeiro, Minas Gerais);
* I<city>: nome da cidade;
* I<ddd>: código DDD (pode estar vazio);
* I<lat>/I<lon>: coordenadas geográficas da cidade (podem estar vazias).

Retorna I<0> quando não foi possível encontrar.

=cut

sub find {
    my ($self, $cep) = @_;
    $cep =~ s/\D//gx;
    if ($self->bsearch($self->length - 1, $cep)) {
        seek($self->data, $self->offset, SEEK_SET) or
            return confess "Can't seek(): $!";

        my $row = $self->csv->getline_hr($self->data);
        my %res = map { $_ => $row->{$_} } qw(state city ddd lat lon);
        $res{state_long}= $self->states->{$res{state}};

        return \%res;
    } else {
        return 0;
    }
}

=method list()

Retorna I<HashRef> com os dados de todas as cidades.

=cut

sub list {
    my ($self) = @_;

    seek($self->data, 0, SEEK_SET) or
        return confess "Can't seek(): $!";

    my %list;
    while (my $row = $self->csv->getline_hr($self->data)) {
        $row->{state_long} = $self->states->{$row->{state}};
        $list{$row->{city} . '/' . $row->{state}} = $row;
    }
    $self->csv->eof
        or carp $self->csv->error_diag;

    return \%list;
}

=head1 SEE ALSO

=for :list
* L<cep2city>
* L<Business::BR::CEP>
* L<WWW::Correios::CEP>
* L<WWW::Correios::PrecoPrazo>
* L<WWW::Correios::SRO>

=head1 CONTRIBUTORS

=for :list
* L<Blabos de Blebe|https://metacpan.org/author/BLABOS>

=cut

1;
