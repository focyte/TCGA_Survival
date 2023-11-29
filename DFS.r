# Author: John @ Focyte
# Created: 22/04/2022
# Version: 1.3
# Description: This script performs survival analysis based on copy number estimation for a specified gene.
#              It organizes patients into groups and generates Kaplan-Meier plots and Cox proportional hazards model results.

### Load required packages
library(survival)
library(survminer)
library(stringr)
library(gridExtra)
library(dplyr)
library(data.table)
library(tidyr)

### create patient survival data frame with disease free survival (DFS) time and status
# import clinical data as a table
df<-read.table("data_clinical_patient.txt", header=T, sep="\t")

# choose relevant columns for DFS survival analysis
clinical_DFS<-data.frame(df$PATIENT_ID, df$DFS_STATUS, df$DFS_MONTHS)

# new headers
colnames(clinical_DFS)<-c("PATIENT_ID", "status", "time")

# convert DFS_STATUS to staus 0/1 > Important for building the survival object
clinical_DFS[clinical_DFS == "0:DiseaseFree"] <- "0"
clinical_DFS[clinical_DFS == "1:Recurred/Progressed"] <- "1"

# remove rows where data is missing (NA) > removes patients with insuffcient clinical data
clinical_DFS<-clinical_DFS %>% drop_na()

### Data handling
# make list of patient ID and sample ID > needed becuase survival and CNA data use different identifiers
ID<-read.table("data_clinical_sample.txt", header=T, sep="\t")
df<-data.frame(ID)
IDS<-data.frame(df$PATIENT_ID, df$SAMPLE_ID)
colnames(IDS)<-c("PATIENT_ID", "SAMPLE_ID")

### Copy Number Analysis (CNA) data
# import CNA data as a table
CNA<-read.table("data_cna.txt", header=F, sep="\t")
df2<-data.frame(CNA)

# convert to dataframe and transpose
df_t <- transpose(df2)

# rename the headers using the gene names
names(df_t) <- as.matrix(df_t[1, ])
df_t <- df_t[-1, ]
df_t <- df_t[-1, ]

### Merge CNA and Survival
names(df_t)[names(df_t) == 'Hugo_Symbol'] <- 'SAMPLE_ID'
CNV_patients<-merge(df_t, IDS, by="SAMPLE_ID")
CNV_clinical<-merge(CNV_patients, clinical_DFS, by="PATIENT_ID")

### Run a test using one gene
#set your gene of interest
gene = CNV_clinical$PTEN
test<-data.frame(CNV_clinical$PATIENT_ID, gene, CNV_clinical$time, CNV_clinical$status)

# new headers
colnames(test)<-c("PATIENT_ID", "gene", "time", "status")
test <- transform(
  test,gene = as.numeric(gene))
test <- transform(
  test,status = as.numeric(status))

# create gene copy number groups
test$gene[test$gene == "0"] <- "1.Diploid"
test$gene[test$gene == "1"] <- "4.Gain"
test$gene[test$gene == "-1"] <- "2.Loss - Shallow"
test$gene[test$gene == "-2"] <- "3.Loss - Deep"

### Suvrvival Object
# create a survival object out of the test data
surv_object <- Surv(time = test$time, event = test$status)


### coxph analysis
# fit a coxph analysis to the data
fit.coxph <- coxph(surv_object ~ gene, 
                   data = test)

# summarise the results
summary(fit.coxph)

# generate a Forest plot of the coxph analysis
ggforest(fit.coxph, data = test)

### KM Plot
# Fit survival data using the Kaplan-Meier method
fit1 <- survfit(surv_object ~ gene, data = test)

# Plot the KM plots
ggsurvplot(fit1, data = test, 
           title = "Effect of PTEN CNV on DFS in Prostate Cancer",
           pval = TRUE, 
           conf.int = TRUE,
           risk.table.col = "strata",
           legend = "right",
           legend.title = "PTEN CNV",
           legend.labs = c("Diploid", "Shallow Loss", "Deep Loss", "Gain"),
           ggtheme = theme_bw() ,
           axes.offset = TRUE,
           pval.method = TRUE,  
           risk.table = TRUE,
           palette = "jco", 
           tables.theme = theme_cleantable())
