FROM ubuntu:xenial
MAINTAINER Susanna Kiwala <ssiebert@wustl.edu>

LABEL \
    description="Image for tools used in the CLE"

RUN apt-get update -y && apt-get install -y \
    wget \
    git \
    unzip \
    bzip2 \
    g++ \
    make \
    zlib1g-dev \
    ncurses-dev \
    perl-doc \
    python \
    rsync \
    default-jdk \
    default-jre \
    bioperl \
    libfile-copy-recursive-perl \
    libarchive-extract-perl \
    libarchive-zip-perl \
    libapache-dbi-perl \
    curl \
    ant \
    emacs 
    
RUN apt-get update -y && apt-get install -y python-pip python-dev build-essential nodejs
RUN pip install --upgrade pip


##########
#GATK 3.6#
##########
ENV maven_package_name apache-maven-3.3.9
ENV gatk_dir_name gatk-protected
ENV gatk_version 3.6
RUN cd /tmp/ && wget -q http://mirror.nohup.it/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.zip

# LSF: Comment out the oracle.jrockit.jfr.StringConstantPool.
RUN cd /tmp/ \
    && git clone --recursive https://github.com/broadgsa/gatk-protected.git \
    && cd /tmp/gatk-protected && git checkout tags/${gatk_version} \
    && sed -i 's/^import oracle.jrockit.jfr.StringConstantPool;/\/\/import oracle.jrockit.jfr.StringConstantPool;/' ./public/gatk-tools-public/src/main/java/org/broadinstitute/gatk/tools/walkers/varianteval/VariantEval.java \
    && mv /tmp/gatk-protected /opt/${gatk_dir_name}-${gatk_version}
RUN cd /opt/ && unzip /tmp/${maven_package_name}-bin.zip \
    && rm -rf /tmp/${maven_package_name}-bin.zip LICENSE NOTICE README.txt \
    && cd /opt/ \
    && cd /opt/${gatk_dir_name}-${gatk_version} && /opt/${maven_package_name}/bin/mvn verify -P\!queue \
    && mv /opt/${gatk_dir_name}-${gatk_version}/protected/gatk-package-distribution/target/gatk-package-distribution-${gatk_version}.jar /opt/GenomeAnalysisTK.jar \
    && rm -rf /opt/${gatk_dir_name}-${gatk_version} /opt/${maven_package_name}

###############
#Varscan 2.4.2#
###############
ENV VARSCAN_INSTALL_DIR=/opt/varscan

WORKDIR $VARSCAN_INSTALL_DIR
RUN wget https://github.com/dkoboldt/varscan/releases/download/2.4.2/VarScan.v2.4.2.jar && \
    ln -s VarScan.v2.4.2.jar VarScan.jar

COPY intervals_to_bed.pl /usr/bin/intervals_to_bed.pl
COPY varscan_helper.sh /usr/bin/varscan_helper.sh

##############
#HTSlib 1.3.2#
##############
ENV HTSLIB_INSTALL_DIR=/opt/htslib

WORKDIR /tmp
RUN wget https://github.com/samtools/htslib/releases/download/1.3.2/htslib-1.3.2.tar.bz2 && \
    tar --bzip2 -xvf htslib-1.3.2.tar.bz2

WORKDIR /tmp/htslib-1.3.2
RUN ./configure  --enable-plugins --prefix=$HTSLIB_INSTALL_DIR && \
    make && \
    make install && \
    cp $HTSLIB_INSTALL_DIR/lib/libhts.so* /usr/lib/

################
#Samtools 1.3.1#
################
ENV SAMTOOLS_INSTALL_DIR=/opt/samtools

WORKDIR /tmp
RUN wget https://github.com/samtools/samtools/releases/download/1.3.1/samtools-1.3.1.tar.bz2 && \
    tar --bzip2 -xf samtools-1.3.1.tar.bz2

WORKDIR /tmp/samtools-1.3.1
RUN ./configure --with-htslib=$HTSLIB_INSTALL_DIR --prefix=$SAMTOOLS_INSTALL_DIR && \
    make && \
    make install

WORKDIR /
RUN rm -rf /tmp/samtools-1.3.1

###############
#bam-readcount#
###############
RUN apt-get update && \
    apt-get install -y \
        cmake \
        patch \
        git

ENV SAMTOOLS_ROOT=/opt/samtools
RUN mkdir /opt/bam-readcount

WORKDIR /opt/bam-readcount
RUN git clone https://github.com/genome/bam-readcount.git /tmp/bam-readcount-0.7.4 && \
    git -C /tmp/bam-readcount-0.7.4 checkout v0.7.4 && \
    cmake /tmp/bam-readcount-0.7.4 && \
    make && \
    rm -rf /tmp/bam-readcount-0.7.4 && \
    ln -s /opt/bam-readcount/bin/bam-readcount /usr/bin/bam-readcount

COPY bam_readcount_helper.py /usr/bin/bam_readcount_helper.py

RUN pip install cyvcf2

#######
#tabix#
#######
RUN ln -s $HTSLIB_INSTALL_DIR/bin/tabix /usr/bin/tabix

########
#VEP 86#
########
RUN mkdir /opt/vep/

WORKDIR /opt/vep
RUN wget https://github.com/Ensembl/ensembl-tools/archive/release/86.zip && \
    unzip 86.zip

WORKDIR /opt/vep/ensembl-tools-release-86/scripts/variant_effect_predictor/
RUN perl INSTALL.pl --NO_HTSLIB

WORKDIR /
RUN ln -s /opt/vep/ensembl-tools-release-86/scripts/variant_effect_predictor/variant_effect_predictor.pl /usr/bin/variant_effect_predictor.pl

RUN mkdir -p /opt/lib/perl/VEP/Plugins
COPY Downstream.pm /opt/lib/perl/VEP/Plugins/Downstream.pm
COPY Wildtype.pm /opt/lib/perl/VEP/Plugins/Wildtype.pm

################
#bcftools 1.3.1#
################
ENV BCFTOOLS_INSTALL_DIR=/opt/bcftools

WORKDIR /tmp
RUN wget https://github.com/samtools/bcftools/releases/download/1.3.1/bcftools-1.3.1.tar.bz2 && \
    tar --bzip2 -xf bcftools-1.3.1.tar.bz2

WORKDIR /tmp/bcftools-1.3.1
RUN make prefix=$BCFTOOLS_INSTALL_DIR && \
    make prefix=$BCFTOOLS_INSTALL_DIR install

WORKDIR /
RUN rm -rf /tmp/bcftools-1.3.1

##############
#Picard 2.4.1#
##############
ENV picard_version 2.4.1

# Install ant, git for building

# Assumes Dockerfile lives in root of the git repo. Pull source files into
# container
RUN cd /usr/ && git config --global http.sslVerify false && git clone --recursive https://github.com/broadinstitute/picard.git && cd /usr/picard && git checkout tags/${picard_version}
WORKDIR /usr/picard

# Clone out htsjdk. First turn off git ssl verification
RUN git config --global http.sslVerify false && git clone https://github.com/samtools/htsjdk.git && cd htsjdk && git checkout tags/${picard_version} && cd ..

# Build the distribution jar, clean up everything else
RUN ant clean all && \
    mv dist/picard.jar picard.jar && \
    mv src/scripts/picard/docker_helper.sh docker_helper.sh && \
    ant clean && \
    rm -rf htsjdk && \
    rm -rf src && \
    rm -rf lib && \
    rm build.xml

COPY split_interval_list_helper.pl /usr/bin/split_interval_list_helper.pl

######
#Toil#
######
RUN pip install toil[cwl]==3.6.0
RUN sed -i 's/select\[type==X86_64 && mem/select[mem/' /usr/local/lib/python2.7/dist-packages/toil/batchSystems/lsf.py

RUN apt-get update -y && apt-get install -y libnss-sss tzdata
RUN ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

#LSF: Java bug that need to change the /etc/timezone.
#     The above /etc/localtime is not enough.
RUN echo "America/Chicago" > /etc/timezone
RUN dpkg-reconfigure --frontend noninteractive tzdata

#############
#verifyBamId#
#############
RUN apt-get update && apt-get install -y build-essential gcc-multilib apt-utils zlib1g-dev git

RUN cd /tmp/ && git clone https://github.com/statgen/verifyBamID.git && git clone https://github.com/statgen/libStatGen.git

RUN cd /tmp/libStatGen && git checkout tags/v1.0.14

RUN cd /tmp/verifyBamID && git checkout tags/v1.1.3 && make

RUN cp /tmp/verifyBamID/bin/verifyBamID /usr/local/bin

RUN rm -rf /tmp/verifyBamID /tmp/libStatGen

###
#R#
###

RUN apt-get update && apt-get install -y r-base r-base-dev littler 

RUN apt-get install -y lib32ncurses5 

