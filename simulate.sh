#!/bin/bash
#RSEM simulation pipeline
#Note to self check dir names. Need to sort out index. Pass an arg to where the raw data is stored instead of requiring it to be moved?

#Function which submits RSEM simulations as LSF style jobs. Takes one arg, the directory where the data to be simulated is stored.
run_simulations(){
  if [ $# -ne 1 ]
    then
      echo "Incorrect number of arguments supplied. One argument should be passed to this function, the path to the directory in which the data is stored."
      exit 1
  fi
  memory=`pwd`
  cd $1
  for i in $(find . -name '*_1.fastq*' -o -name '*_1.fq*');
  do
    base=`echo $i |awk -F/ '{print $2}'`
    filename=`echo $base |awk -F_ '{print $1}'`
    cd $memory
    #The line below will need to be edited for your LSF job system.
    bsub -n8 -R"span[hosts=1]" -c 99999 -G team_hemberg -q normal -o $TEAM/temp.logs/output.$filename -e $TEAM/temp.logs/error.$filename -R"select[mem>100000] rusage[mem=100000]" -M100000 simulate $i $1
  done
}

#Function which performs RSEM simulations. Takes 2 args, the filename of the cell and the directory in which it is stored.
simulate() {


 #Make filename strings
 filename=`echo $1 | rev | cut -d _ -f2- | rev`
 end=`echo $1 |awk -F. '{print $2}'`
 filename_1=$filename"_1."$end
 filename_2=$filename"_2."$end
 raw_data_dir=${2%/}

 lines="$(wc -l $raw_data_dir/$filename_1 | awk '{print $1}')"
 reads="$(echo $((lines / 4)))"

#process bulk without single cell priors
 if [ "$filename" == "ERR522956" ]
 then
   echo 'bulk sample being simulated'
   #Use RSEM to calculate expression
   ./Simulation/RSEM-1.3.0/rsem-calculate-expression --paired-end --star\
         --star-path Simulation/STAR/bin/Linux_x86_64/ \
         -p 8 \
                     --estimate-rspd \
                     --append-names \
                     --output-genome-bam \
                     $raw_data_dir/$filename_1 $raw_data_dir/$filename_2 \
                     Simulation/ref/reference Simulation/data/temp/$filename
  else
    #Use RSEM to calculate expression
    ./Simulation/RSEM-1.3.0/rsem-calculate-expression --paired-end --star\
          --star-path Simulation/STAR/bin/Linux_x86_64/ \
          -p 8 \
                      --estimate-rspd \
                      --append-names \
                      --output-genome-bam \
          --single-cell-prior --calc-pme \
                      $raw_data_dir/$filename_1 $raw_data_dir/$filename_2 \
                      Simulation/ref/reference Simulation/data/temp/$filename
  fi



 #extract first number of third line of filename.theta, which is an estimate of the portion of reads due to background noise
 background_noise=`sed '3q;d' Simulation/data/temp/$filename".stat"/$filename".theta" | awk '{print $1}'`


 #Simulate reads
 ./Simulation/RSEM-1.3.0/rsem-simulate-reads Simulation/ref/reference Simulation/data/temp/$filename".stat"/$filename".model" \
                       Simulation/data/temp/$filename".isoforms.results" $background_noise $reads Simulation/data/simulated/$filename \
                       --seed 0

}

export -f simulate

"$@"
