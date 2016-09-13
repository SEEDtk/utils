use strict;
use FIG_Config;
use Job;

my $jobObject = Job->new('', ['time=i', 'number of intervals to wait', { default => 10 }]);
my $time = $jobObject->opt->time;
for (my $i = 1; $i <= $time; $i++) {
    $jobObject->Progress("Starting sleep interval $i.");
    sleep 2;
}
$jobObject->Finish("$time intervals completed.");