#####################################################
# ~ miseqUtils: function callMutations ~
#
#
# Francois Kroll 2024
# francois@kroll.be
#####################################################

# loops through CRISPResso output folders

# copath = folder that contains the CRISPResso results directories

callMutations <- function(copath,
                          metapath,
                          minnreads=NA,
                          cutpos=NA,
                          cutdist=NA,
                          rhapos=NA,
                          rhadist=NA,
                          controltb=NA,
                          callSubs=TRUE,
                          exportpath) {
  ### check export path ends with .csv
  frmt <- substr(exportpath, start=nchar(exportpath)-2, stop=nchar(exportpath))
  if(frmt!='csv')
    stop('\t \t \t \t >>> exportpath should end with .csv.\n')
  
  ### import meta file
  # check file exists
  if(!file.exists(metapath))
    stop('\t \t \t \t >>> Error: cannot find ', metapath, '.\n')
  # check it finishes by .xlsx
  frmt <- substr(metapath, start=nchar(metapath)-3, stop=nchar(metapath))
  if(frmt!='xlsx')
    stop('\t \t \t \t >>> Expecting meta file to be .xlsx.\n')
  # import it
  meta <- read.xlsx(metapath)
  # check it has columns rundate & well & locus
  if(!'rundate' %in% colnames(meta))
    stop('\t \t \t \t >>> Error: expecting column "rundate" in meta file.\n')
  if(!'well' %in% colnames(meta))
    stop('\t \t \t \t >>> Error: expecting column "well" in meta file.\n')
  if(!'locus' %in% colnames(meta))
    stop('\t \t \t \t >>> Error: expecting column "locus" in meta file.\n')
  
  ### find CRISPResso output directories
  dirs <- list.dirs(copath)
  # first one is current directory, skip it
  dirs <- dirs[2:length(dirs)]
  # which ones are CRISPResso result directories?
  dirs <- dirs[startsWith(basename(dirs), 'CRISPResso')]
  
  ### find alleles table
  # loop through the directories,
  mutL <- lapply(1:length(dirs), function(di) {
    cat('\n')
    # path to Alleles_frequency_table.zip should be:
    alzip <- paste(dirs[di], 'Alleles_frequency_table.zip', sep='/')
    # check we found it
    if(!file.exists(alzip))
      stop('\t \t \t \t >>> Error: expecting Alleles_frequency_table.zip in folder', dirs[di], '.\n')
    # unzip it in same folder
    unzip(alzip, exdir=  dirname(alzip))
    # check unzipped file exists
    # should be same as zip, but with .txt
    altxt <- paste0(substr(alzip, start=1, stop=nchar(alzip)-3), 'txt')
    if(!file.exists(altxt))
      stop('\t \t \t \t >>> Error: after unzipping, expecting Alleles_frequency_table.txt in folder', dirs[di], '.\n')
    
    ### convert alleles table to mutation table
    cat('\t \t \t \t >>> Calling mutations from', altxt,'\n')
    muttb <- allelesToMutations(alpath=altxt)
    
    ### filter the detected mutations
    cat('\t \t \t \t >>> Filtering mutation calls.\n')
    mutf <- filterMutations(muttb=muttb,
                            minnreads=minnreads,
                            cutpos=cutpos,
                            cutdist=cutdist,
                            rhapos=rhapos,
                            rhadist=rhadist,
                            controltb=controltb,
                            callSubs=callSubs)
    
    ### add column well & column locus
    # from meta,
    # unique well names are:
    wells <- unique(meta$well)
    # unique locus names are:
    loci <- unique(meta$locus)
    # from the folder name,
    ## try to find well name
    # assumption: well name is in the folder name between some _
    dirsplit <- unlist(strsplit(basename(dirs[di]), '_'))
    wellnm <- dirsplit[which(dirsplit %in% wells)][1] # we take first occurence of that looks like well name
    if(length(wellnm)==0)
      stop('\t \t \t \t >>> Error: did not find well name in directory name', dirs[di], '\n')
    ## try to find locus name
    locnm <- dirsplit[which(dirsplit %in% loci)][1] # we take first occurence of that looks like locus name
    if(length(locnm)==0)
      stop('\t \t \t \t >>> Error: did not find locus name in directory name', dirs[di], '\n')
    ## check that it makes sense in comparison with meta
    # i.e. that this well coordinate has this locus
    metarow <- intersect(which(meta$well==wellnm), which(meta$locus==locnm))
    if(length(metarow)==0)
      stop('\t \t \t \t >>> Error: there is no row in meta file that has well ', wellnm, ' and locus ', locnm,'.\n')
    if(length(metarow)>1)
      stop('\t \t \t \t >>> Error: there are multiple rows in meta file that has well ', wellnm, ' and locus ', locnm,'. Please make well/locus unique.\n')
    ## add meta information to mutation table
    # TODO: here could be good to just add all meta columns?
    mutf <- mutf %>%
      mutate(locus=meta[metarow, 'locus'], .before=1) %>%
      mutate(well=meta[metarow,'well'], .before=1) %>%
      mutate(rundate=meta[metarow,'rundate'], .before=1)
    # also add both to use as unique sample ID
    mutf <- mutf %>%
      mutate(sample=paste(rundate, well, locus, sep='_'), .before=1)
    
    ### return filtered mutations
    return(mutf)
    
  })
  # we get list mutL which is table of filtered mutations for each sample
  # gather everything in one dataframe
  # we have locus & well to keep track of which mutation is from which sample
  mut <- do.call(rbind, mutL)
  # save this dataframe
  # prepare filename
  write.csv(mut, exportpath, row.names=FALSE)
  cat('\t \t \t \t >>> Wrote', exportpath, '\n')
  # we also return mut
  invisible(mut)
}
