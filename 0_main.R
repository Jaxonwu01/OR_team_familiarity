################################################################
################################################################
######  Main file for OR team composition analyses
################################################################
################################################################################

library(here)
library(config)


debuggingState(on = FALSE)
Sys.setenv(R_CONFIG_ACTIVE = 'default')
config <- config::get()


source(here('1_funcsV2.R'), echo = TRUE)


#########################
#### cleaning data and loading into DB
#########################

df_cases <- get_and_clean_cases(
  data_dir = config$data_dir,
  cases_file = config$cases_file,
  cpt_file = config$cpt_file)

df_proviers <- get_and_clean_providers(
  data_dir = config$data_dir,
  providers_file = config$providers_file,
  remove_dupes = TRUE # this addresses the issue of people being on a single case multiple times
)

# loads data to the postgress DB
push_cases_providers_to_db(
  con = DBI::dbConnect(RPostgres::Postgres(),
                              dbname   = config$db_name,
                              host     = 'localhost',
                              port     = config$port,
                              user     = config$db_user,
                              password = config$db_pw),
  df_cases = NA,
  df_providers = df_providers
)

#########################
#### Preparing data and db for a specific analysis
#########################

fam_df <- prep_data_for_fam_metrics(
  df_cases = df_cases, #%>% filter(log_id %in% unique(big_zetas$log_id)),
  df_providers = df_providers,
  shared_work_experience_window_weeks = config$shared_work_experience_window_weeks)

# Need to run this twice if using the cmbd_dyad_borg_par_db function (once with each dyad and borg table suffix)
prep_DB_for_fam_metrics(
  df_cases = df_cases,
  df_providers = df_providers,
  table_suffix = config$dyad_table_suffix,
  # table_suffix = config$borg_table_suffix,
  shared_work_experience_window_weeks = config$shared_work_experience_window_weeks,
  con = DBI::dbConnect(RPostgres::Postgres(),
                       dbname   = config$db_name,
                       host     = 'localhost',
                       port     = config$port,
                       user     = config$db_user,
                       password = config$db_pw)
)

source('2_make_fam_metrics_db.R')



#########################
#### Mess below here
#########################


### Use if processing stops before all cases done
fam_df <- get_unprocessed(
  con = DBI::dbConnect(RPostgres::Postgres(),
                       dbname   = config$db_name,
                       host     = 'localhost',
                       port     = config$port,
                       user     = config$db_user,
                       password = config$db_pw),
  df = fam_df,
  table_suffix = config$dyad_table_suffix,
  shared_work_experience_window_weeks = config$shared_work_experience_window_weeks
  )

fam_by_perf_df <- get_perf_fam_metrics(
  df_cases = df_cases,
  table_suffix = config$dyad_table_suffix,
  con = DBI::dbConnect(RPostgres::Postgres(),
                       dbname   = config$db_name,
                       host     = 'localhost',
                       port     = config$port,
                       user     = config$db_user,
                       password = config$db_pw)
)


#################################

x <- run_audit(
  con = DBI::dbConnect(RPostgres::Postgres(),
                       dbname   = config$db_name,
                       host     = 'localhost',
                       port     = config$port,
                       user     = config$db_user,
                       password = config$db_pw),
  tname = 'team_comp_metrics_v2_fifty_perc_rt' #'team_comp_metrics'#
)
write_csv(x,'audit.csv')

#### Dump contents of the cases and perf metrics so I can work on models while this runs on PC w/ PG DB
tcon <- DBI::dbConnect(RPostgres::Postgres(),
                       dbname   = config$db_name,
                       host     = 'localhost',
                       port     = config$port,
                       user     = config$db_user,
                       password = config$db_pw)
all_cases <- tcon %>% tbl('team_comp_metrics_v2_all_staff') %>% collect()
all_cases %>% write_csv(.,'all_cases_all_staff.csv')
all_cases <- tcon %>% tbl('cases') %>% collect()
all_cases %>% write_csv(.,'cases.csv')

big_zetas <- tcon %>% tbl('team_comp_metrics_v2_fifty_perc_rt') %>%
  filter(zeta_prime_1 > 1) %>% collect()


x <- pullAllTeamCompMetrics(
  con = DBI::dbConnect(RPostgres::Postgres(),
                       dbname   = config$db_name,
                       host     = 'localhost',
                       port     = config$port,
                       user     = config$db_user,
                       password = config$db_pw)
)

skimr::skim(x)

x %>% 
  filter(stts == TRUE & coreTeam == TRUE) %>%
  select(zeta_4) %>%
  table()

write_csv(x,here(config$data_dir,'combinedTeamCompMetrics.csv'))

x %>%
  group_by(stts,coreTeam) %>%
  summarize(prop_na = sum(is.na(zeta_prime_52))/n())


