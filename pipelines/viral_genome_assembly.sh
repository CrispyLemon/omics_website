#### Viral Genome Assembly ####

GENOMEIDX1="/mnt/c/Users/asus/genome_assembly/genome_sars_cov2/NC_045512.2.fasta"
## Step-0 (Build reference genome index)
bowtie2-build ${GENOMEIDX1} sars_cov2

BASEDIRDATA="$(pwd)"
reads1=(${BASEDIRDATA}/*_1.fastq.gz)
reads1=("${reads1[@]##*/}")
#echo ${reads1[@]}
reads2=("${reads1[@]/_1./_2.}")

echo "***Following SAMPLES are submitted for Germline variant calling***"
for ((i=0; i<=${#reads1[@]}-1; i++ )); do
    #sample="${reads1[$i]%%.*}"
    sample="${reads1[$i]%1_*}"
    sample="${sample%_*}"
    echo "$sample"
    done

for ((i=0; i<=${#reads1[@]}-1; i++ )); do
    sample="${reads1[$i]%1_*}"
    sample="${sample%_*}"
    stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Processing sample: $sample"
echo "$stime Step-1.0 (FastQC Quality Control Report)"
#fastqc -o fastqc_output/ ${BASEDIRDATA}/${sample}_R1.fastq.gz ${BASEDIRDATA}/${sample}_R2.fastq.gz
fastqc SRR21139865_1.fastq.gz SRR21139865_2.fastq.gz

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-1.1 (Fastp Quality Control)"
fastp -i ${BASEDIRDATA}/${sample}_R1.fastq.gz -o ${BASEDIRDATA}/${sample}_P1.fastq -I ${BASEDIRDATA}/${sample}_R2.fastq.gz -O ${BASEDIRDATA}/${sample}_P2.fastq --thread 4 -h ${BASEDIRDATA}/"fastp-${sample}.html" 2> "${BASEDIRDATA}/fastp-${sample}.log"
#fastp -i SRR21139865_1.fastq.gz -o SRR21139865_P1.fastq -I SRR21139865_2.fastq.gz -O SRR21139865_P2.fastq --thread 4 -h "fastp-SRR21139865.html" 2> "fastp-SRR21139865.log"

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-2 (Read Alignment)"
#bowtie2 -p 64 -x /ibdc-analysis/IBDC-BRAHM-ANALYSIS/genome/insacog/NC_045512.2.fasta -1 ${BASEDIRDATA}/${sample}_P1.fastq -2 ${BASEDIRDATA}/${sample}_P2.fastq -S ${BASEDIRDATA}/${sample}.sam 
bowtie2 -p 64 -x /mnt/c/Users/asus/genome_assembly/genome_sars_cov2/sars_cov2 -1 SRR21139865_P1.fastq -2 SRR21139865_P2.fastq -S SRR21139865.sam 

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-3 (Conversion Of Sam To BAM File)"
#samtools view -b ${BASEDIRDATA}/${sample}.sam -o ${BASEDIRDATA}/${sample}.bam 
samtools view -b SRR21139865.sam -o SRR21139865.bam 

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-4 (Alignment Metrics)"
#samtools flagstat ${BASEDIRDATA}/${sample}.bam > ${BASEDIRDATA}/${sample}.flagstat.txt
samtools flagstat SRR21139865.bam > SRR21139865.flagstat.txt

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-5 (Conversion of BAM To Sorted BAM)"
#samtools sort ${BASEDIRDATA}/${sample}.bam -o ${BASEDIRDATA}/${sample}.sorted.bam 
samtools sort SRR21139865.bam -o SRR21139865.sorted.bam 

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-6 (Deriving Low Coverage Bed File)"
samtools depth SRR21139865.sorted.bam | awk '$3 < 5 {print $1"\t"$2"\t"$3}' > coverage.txt

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-7 (run script to extract start end coordinates of missing read segments)"
python3 extract_intervalsforBED.py

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-8 (Performing N-masking)"
bedtools maskfasta -fi ${BASEDIRDATA}/NC_045512.2.fasta -bed ${BASEDIRDATA}/${sample}_low_coverage_regions.bed -mc N -fo {BASEDIRDATA}/${sample}_masked.fasta
bedtools maskfasta -fi /mnt/c/Users/asus/genome_assembly/genome_sars_cov2/NC_045512.2.fasta -bed SRR21139865_low_coverage_regions_1.bed -mc N -fo SRR21139865_masked.fasta

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-9 (Remove duplicate reads from Sorted Bam Files)"
samtools rmdup -S ${BASEDIRDATA}/${sample}.sorted.bam ${BASEDIRDATA}/${sample}.duprem.bam
samtools rmdup -S SRR21139865.sorted.bam SRR21139865.duprem.bam

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-10 (Generation of vcf)"
bcftools mpileup -f /mnt/c/Users/asus/genome_assembly/genome_sars_cov2/NC_045512.2.fasta SRR21139865.duprem.bam | bcftools call -cv --ploidy 1 -Oz -o SRR21139865.vcf.gz

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-11 (generation of vcf index)"
bcftools index SRR21139865.vcf.gz

stime=`date +"%Y-%m-%d %H:%M:%S"`
echo "$stime Step-12 (Generation of viral genome fasta)"
cat SRR21139865_masked.fasta | bcftools consensus SRR21139865.vcf.gz > SRR21139865_genome.fa

rm ${sample}.sam
rm ${BASEDIRDATA}/${sample}_P1.fastq
rm ${BASEDIRDATA}/${sample}_P2.fastq

done