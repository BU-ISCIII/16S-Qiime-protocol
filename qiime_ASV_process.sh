#!/bin/bash
MANIFEST = "$1"
METADATA = "$2"


mkdir importsequences

qiime tools import \
--type 'SampleData[PairedEndSequencesWithQuality]' \
--input-path $MANIFEST \
--output-path importsequences/paired-end-demux.qza \
--input-format PairedEndFastqManifestPhred33V2

qiime demux summarize \
--i-data importsequences/paired-end-demux.qza \
--o-visualization importsequences/paired-end.demux.qzv


# denoising
#####################################
mkdir dada2_result

qiime dada2 denoise-paired \
--i-demultiplexed-seqs importsequences/paired-end-demux.qza \
--p-trunc-len-f 0 \
--p-trunc-len-r 0 \
--p-n-threads 0 \ #max possible
--o-representative-sequences dada2_result/rep_seqs_dada2.qza \
--o-table dada2_result/featuretable_dada2.qza \
--o-denoising-stats dada2_result/stats_dada2.qza

# tabular secuencias representativas
qiime metadata tabulate \
--m-input-file dada2_result/rep_seqs_dada2.qza \
--o-visualization dada2_result/rep_seqs_dada2.qzv

# tabular estadísticas
qiime metadata tabulate 
 --m-input-file dada2_result/stats-dada2.qza 
 --o-visualization dada2_result/stats-dada2.qzv

# tabular feature table
qiime metadata tabulate \
--m-input-file dada2_result/feature_table_dada2.qza \
--o-visualization dada2_result/feature_table_dada2.qzv

# tabular feature table con metadatos
qiime feature-table summarize \
--i-table dada2_result/feature_table_dada2.qza \
--o-visualization dada2_result/feature_table_dada2_summarized.qzv \
--m-sample-metadata-file $METADATA

# tabular feature con identificador al mapeado
qiime feature-table tabulate-seqs \
--i-data dada2_result/feature_table_dada2.qza \
--o-visualization dada2_result/feature_table_tabulated_seqs.qzv

############################################
mkdir phylogeny_data

# alinear al arbol
qiime phylogeny align-to-tree-mafft-fasttree \
--i-sequences dada2_result/rep_seqs_dada2.qza \
--o-alignment phylogeny_data/aligned_rep_seqs.qza \
--o-masked-alignment phylogeny_data/masked_aligned_rep_seqs.qza \
--o-tree phylogeny_data/unrooted_tree.qza \
--o-rooted-tree phylogeny_data/rooted_tree.qza

###################################################
mkdir diversity_data

qiime diversity core-metrics-phylogenetic \
--i-phylogeny phylogeny_data/rooted_tree.qza \
--i-table dada2_result/feature_table_dada2.qza \
--p-sampling-depth [] \ #DEFINIR SAMPLE DEPTH
--m-metadata-file $METADATA \
--output-dir diversity_data

# diversidad alfa con faith
qiime diversity alpha-group-significance \
--i-alpha-diversity diversity_data/faith_pd_vector.qza \
--m-metadata-file $METADATA \
--o-visualization diversity_data/faith_pd_summarized.qzv

# diversidad alfa con pielou
qiime diversity alpha-group-significance \
--i-alpha-diversity diversity_data/evenness_vector.qza \
--m-metadata-file $METADATA \
--o-visualization diversity_data/evenness_vector_summarized.qzv

# diversidad alfa de shannon
qiime diversity alpha-group-significance \
--i-alpha-diversity diversity_data/shannon_vector.qza \
--m-metadata-file $METADATA \
--o-visualization diversity_data/shannon_vector_summarized.qzv

# diversidad beta por especies
qiime diversity beta-group-significance \
--i-distance-matrix diversity_data/unweighted_unifrac_distance_matrix.qza \
--m-metadata-file $METADATA \
--m-metadata-column species \
--o-visualization diversity_data/unweighted_unifrac_species_significance.qzv \
--p-pairwise

# diversidad beta por as
qiime diversity beta-group-significance \
--i-distance-matrix diversity_data/unweighted_unifrac_distance_matrix.qza \
--m-metadata-file $METADATA \
--m-metadata-column as \
--o-visualization diversity_data/unweighted_unifrac_as_significance.qzv \
--p-pairwise

# diversidad beta por endophyte
qiime diversity beta-group-significance \
--i-distance-matrix diversity_data/unweighted_unifrac_distance_matrix.qza \
--m-metadata-file $METADATA \
--m-metadata-column endophyte \
--o-visualization diversity_data/unweighted_unifrac_endophyte_significance.qzv \
--p-pairwise

# diversidad beta por blocking_primers
qiime diversity beta-group-significance \
--i-distance-matrix diversity_data/unweighted_unifrac_distance_matrix.qza \
--m-metadata-file $METADATA \
--m-metadata-column blocking_primers \
--o-visualization diversity_data/unweighted_unifrac_species_significance.qzv \
--p-pairwise

####################################################
mkdir alpha_rarefaction

qiime diversity alpha-rarefaction \
--i-table dada2_result/featuretable_dada2.qza \
--i-phylogeny phylogeny_data/rooted_tree.qza \
--p-max-depth [] \
--m-metadata-file $METADATA\
--p-iterations [] \
--o-visualization alpha_rarefaction/alpha_rarefaction.qzv

#######################################################
mkdir taxonomy

# Descarga del modelo
wget -O taxonomy/gg-13-8-99-nb-classifier.qza https://data.qiime2.org/2021.2/common/gg-13-8-99-nb-classifier.qza

# Utiliza el modelo para clasificar
qiime feature-classifier classify-sklearn \
--i-classifier taxonomy/gg-13-8-99-nb-classifier.qza \
--i-reads dada2_result/rep_seqs_dada2.qza \ #repseqs
--o-classification taxonomy/taxonomy.qza

qiime metadata tabulate \
--m-input-file taxonomy/taxonomy.qza \
--o-visualization taxonomy/taxonomy.qzv

qiime taxa barplot \ 
--i-table dada2_result/featuretable_dada2.qza \
--i-taxonomy taxonomy/taxonomy.qza \
--m-metadata-file $METADATA \
--o-visualization taxonomy/taxa-bar-plots.qzv

qiime feature-table filter-samples \
--i-table ../04-qiime/01-dada2/table-dada2.qza \
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \
--p-where "[species]='J.montana'" \
--o-filtered-table ../04-qiime/07-differencial-abundance/montana-table.qza

qiime feature-table filter-samples \
--i-table ../04-qiime/01-dada2/table-dada2.qza \
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \
--p-where "[species]='J.sessiliflora'" \
--o-filtered-table ../04-qiime/07-differencial-abundance/sessiliflora-table.qza

qiime feature-table filter-samples \ 
--i-table ../04-qiime/01-dada\ 
--
--o-filtered-table ../04-qiime/07-differencial-abundance/As-table.qza

qiime feature-table filter-samples \ 
--i-table ../04-qiime/01-dada2/table-dada2.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--p-where "[as]='no'" \ 
--o-filtered-table ../04-qiime/07-differencial-abundance/noAs-table.qza

qiime feature-table filter-samples \ 
--i-table ../04-qiime/01-dada2/table-dada2.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--p-where "[endophyte]='yes'" \ 
--o-filtered-table ../04-qiime/07-differencial-abundance/endophyte-table.qza

qiime feature-table filter-samples \ 
--i-table ../04-qiime/01-dada2/table-dada2.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--p-where "[endophyte]='no'" \ 
--o-filtered-table ../04-qiime/07-differencial-abundance/noendophyte-table.qza

qiime feature-table filter-samples \ 
--i-table ../04-qiime/01-dada2/table-dada2.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--p-where "[blocking-primers]='no'" \ 
--o-filtered-table ../04-qiime/07-differencial-abundance/noblockingprimers-table.qza

qiime feature-table filter-samples \ 
--i-table ../04-qiime/01-dada2/table-dada2.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--p-where "[blocking-primers]='yes'" \ 
--o-filtered-table ../04-qiime/07-differencial-abundance/yesblockingprimers-table.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/montana-table.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-montana-table.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/sessiliflora-table.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-sessiliflora-table.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/As-table.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-As-table.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/noAs-table.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-noAs-table.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/endophyte-table.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-endophyte-table.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/noendophyte-table.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-noendophyte-table.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/noblockingprimers-table.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-noblockingprimers-table.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/yesblockingprimers-table.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-yesblockingprimers-table.qza

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-montana-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/montana-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-montana-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/montana-ancom-endophyte.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-montana-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/montana-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-sessiliflora-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/sessiliflora-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-sessiliflora-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/sessiliflora-ancom-endophyte.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-sessiliflora-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/sessiliflora-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-As-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/As-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-As-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/As-ancom-endophyte.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-As-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/As-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noAs-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/noAs-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noAs-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/noAs-ancom-endophyte.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noAs-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/noAs-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-endophyte-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/endophyte-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-endophyte-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/endophyte-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-endophyte-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ ^\\
--o-visualization ../04-qiime/07-differencial-abundance/endophyte-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noendophyte-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/noendophyte-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noendophyte-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ ^\\
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/noendophyte-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noendophyte-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/noendophyte-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noblockingprimers-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/noblockinprimers-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noblockingprimers-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/noblockingprimers-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noblockingprimers-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/noblockingprimers-ancom-endophyte.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-yesblockingprimers-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/yesblockinprimers-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-yesblockingprimers-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/yesblockingprimers-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-yesblockingprimers-table.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/yesblockingprimers-ancom-endophyte.qzv

qiime taxa collapse \ 
--i-table ../04-qiime/07-differencial-abundance/montana-table.qza \ 
--i-taxonomy ../04-qiime/06-taxonomy/taxonomy.qza \ 
--p-level 7 \ 
--o-collapsed-table ../04-qiime/07-differencial-abundance/montana-table-lv7.qza

qiime taxa collapse \ 
--i-table ../04-qiime/07-differencial-abundance/sessiliflora-table.qza \ 
--i-taxonomy ../04-qiime/06-taxonomy/taxonomy.qza \ 
--p-level 7 \ 
--o-collapsed-table ../04-qiime/07-differencial-abundance/sessiliflora-table-lv7.qza

qiime taxa collapse \ 
--i-table ../04-qiime/07-differencial-abundance/As-table.qza \ 
--i-taxonomy ../04-qiime/06-taxonomy/taxonomy.qza \ 
--p-level 7 \ 
--o-collapsed-table ../04-qiime/07-differencial-abundance/as-table-lv7.qza

qiime taxa collapse \ 
--i-table ../04-qiime/07-differencial-abundance/noAs-table.qza \ 
--i-taxonomy ../04-qiime/06-taxonomy/taxonomy.qza \ 
--p-level 7 \ 
--o-collapsed-table ../04-qiime/07-differencial-abundance/noas-table-lv7.qza

qiime taxa collapse \ 
--i-table ../04-qiime/07-differencial-abundance/endophyte-table.qza \ 
--i-taxonomy ../04-qiime/06-taxonomy/taxonomy.qza \ 
--p-level 7 \ 
--o-collapsed-table ../04-qiime/07-differencial-abundance/endophyte-table-lv7.qza

qiime taxa collapse \ 
--i-table ../04-qiime/07-differencial-abundance/noendophyte-table.qza \ 
--i-taxonomy ../04-qiime/06-taxonomy/taxonomy.qza \ 
--p-level 7 \ 
--o-collapsed-table ../04-qiime/07-differencial-abundance/noendophyte-table-lv7.qza

qiime taxa collapse \ 
--i-table ../04-qiime/07-differencial-abundance/yesblockingprimers-table.qza \ 
--i-taxonomy ../04-qiime/06-taxonomy/taxonomy.qza \ 
--p-level 7 \ 
--o-collapsed-table ../04-qiime/07-differencial-abundance/yesblockingprimers-table-lv7.qza

qiime taxa collapse \ 
--i-table ../04-qiime/07-differencial-abundance/noblockingprimers-table.qza \ 
--i-taxonomy ../04-qiime/06-taxonomy/taxonomy.qza \ 
--p-level 7 \ 
--o-collapsed-table ../04-qiime/07-differencial-abundance/noblockingprimers-table-lv7.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/montana-table-lv7.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-montana-table-lv7.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/sessiliflora-table-lv7.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-sessiliflora-table-lv7.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/as-table-lv7.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-as-table-lv7.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/noas-table-lv7.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-noas-table-lv7.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/endophyte-table-lv7.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-endophyte-table-lv7.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/noendophyte-table-lv7.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-noendophyte-table-lv7.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/yesblockingprimers-table-lv7.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-yesblockingprimers-table-lv7.qza

qiime composition add-pseudocount \ 
--i-table ../04-qiime/07-differencial-abundance/noblockingprimers-table-lv7.qza \ 
--o-composition-table ../04-qiime/07-differencial-abundance/comp-noblockingprimers-table-lv7.qza

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-montana-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-montana-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-montana-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-montana-ancom-endophyte.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-montana-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-montana-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-sessiliflora-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-sessiliflora-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-sessiliflora-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-sessiliflora-ancom-endophyte.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-sessiliflora-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-sessiliflora-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-as-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-as-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-as-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-as-ancom-endophyte.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-as-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-as-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noas-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-noas-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noas-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-noas-ancom-endophyte.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noas-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-noas-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-endophyte-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-endophyte-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-endophyte-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-endophyte-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-endophyte-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-endophyte-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noendophyte-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-noendophyte-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noendophyte-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-noendophyte-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noendophyte-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column blocking-primers \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-noendophyte-ancom-blockingprimers.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-yesblockingprimers-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-yesblockingprimers-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-yesblockingprimers-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-yesblockingprimers-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-yesblockingprimers-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-yesblockingprimers-ancom-endophyte.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noblockingprimers-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column species \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-noblockingprimers-ancom-species.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noblockingprimers-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column as \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-noblockingprimers-ancom-as.qzv

qiime composition ancom \ 
--i-table ../04-qiime/07-differencial-abundance/comp-noblockingprimers-table-lv7.qza \ 
--m-metadata-file /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/samples-metadata.tsv \ 
--m-metadata-column endophyte \ 
--o-visualization ../04-qiime/07-differencial-abundance/lv7-noblockingprimers-ancom-endophyte.qzv

qiime taxa filter-seqs \
--i-sequences /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS//04-qiime/01-dada2/rep-seqs-dada2.qza \
--i-taxonomy /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/06-taxonomy/taxonomy.qza \
--p-include Pseudomonas --o-filtered-sequences /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Pseudomonas.qza

qiime taxa filter-seqs \
--i-sequences /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS//04-qiime/01-dada2/rep-seqs-dada2.qza \
--i-taxonomy /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/06-taxonomy/taxonomy.qza --p-include Undibacterium \
--o-filtered-sequences /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Undibacterium.qza

qiime taxa filter-seqs \
--i-sequences /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS//04-qiime/01-dada2/rep-seqs-dada2.qza \
--i-taxonomy /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/06-taxonomy/taxonomy.qza º
--p-include Ralstonia \
--o-filtered-sequences /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Ralstonia.qza

qiime taxa filter-seqs \
--i-sequences /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS//04-qiime/01-dada2/rep-seqs-dada2.qza \
--i-taxonomy /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/06-taxonomy/taxonomy.qza \
--p-include Cutibacterium \
--o-filtered-sequences /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Cutibacterium.qza

qiime taxa filter-seqs \
--i-sequences /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS//04-qiime/01-dada2/rep-seqs-dada2.qza \
--i-taxonomy /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/06-taxonomy/taxonomy.qza \
--p-include Comamonadaceae \
--o-filtered-sequences /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Comamonadaceae.qza
 
qiime tools export \
--input-path /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Pseudomonas.qza \
--output-path /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Pseudomonas.fasta

qiime tools export \
--input-path /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Undibacterium.qza \
--output-path /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Undibacterium.fasta

qiime tools export \
--input-path /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Ralstonia.qza \
--output-path /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Ralstonia.fasta

qiime tools export \
--input-path /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Cutibacterium.qza \
--output-path /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Cutibacterium.fasta

qiime tools export \
--input-path /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Comamonadaceae.qza \
--output-path /home/scratch/irene/project_Natalia16S-bloq/ANALYSIS/04-qiime/08-filtered-sequences/Comamonadaceae.fasta
