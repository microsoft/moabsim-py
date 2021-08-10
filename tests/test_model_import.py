"""
Pytest for confirming model import assessment works using Telescope data
retrieval from LogAnalyticsDataClient. Usage:

Train a brain using model import's instructions, then run

pytest tests/test_model_import.py -s \
    --brain_name <BRAIN_NAME> \
    --log_analy_workspace <LAW_WORKSPACE_ID> \
    --custom_assess_name <CUSTOM_ASSESSMENT_NAME> \
    --model_file_path "./Machine-Teaching-Examples/model_import/state_transform_deep.zip"

    or 
    --model_file_path "./Machine-Teaching-Examples/model_import/state_transform_deep.onnx"
"""

__author__ = "Journey McDowell"
__copyright__ = "Copyright 2021, Microsoft Corp."

import os
import pytest
import glob
import pandas as pd
import numpy as np
from azure.loganalytics import LogAnalyticsDataClient
from azure.common.credentials import get_azure_cli_credentials
from azure.loganalytics.models import QueryBody
import ast
import json
import matplotlib.pyplot as plt
import time
import pdb

# Allowing optional flags to replace defaults for pytest from tests/conftest.py
@pytest.fixture()
def brain_name(pytestconfig):
    return pytestconfig.getoption("brain_name")

@pytest.fixture()
def brain_version(pytestconfig):
    return pytestconfig.getoption("brain_version")

@pytest.fixture()
def concept_name(pytestconfig):
    return pytestconfig.getoption("concept_name")

# json file with assessment configs for input
@pytest.fixture()
def file_name(pytestconfig):
    return pytestconfig.getoption("file_name")

@pytest.fixture()
def simulator_package_name(pytestconfig):
    return pytestconfig.getoption("simulator_package_name")

@pytest.fixture()
def inkling_fname(pytestconfig):
    return pytestconfig.getoption("inkling_fname")

@pytest.fixture()
def instance_count(pytestconfig):
    return pytestconfig.getoption("instance_count")

@pytest.fixture()
def custom_assess_name(pytestconfig):
    return pytestconfig.getoption("custom_assess_name")

@pytest.fixture()
def log_analy_workspace(pytestconfig):
    return pytestconfig.getoption("log_analy_workspace")

@pytest.fixture()
def import_name(pytestconfig):
    return pytestconfig.getoption("import_name")

@pytest.fixture()
def model_file_path(pytestconfig):
    return pytestconfig.getoption("model_file_path")

# Use CLI to import a ML model as .onnx or tf
def test_model_import(import_name, model_file_path):
    os.system('bonsai importedmodel create --name "{}" --modelfilepath {}'.format(
        import_name,
        model_file_path,
    ))
    
    os.system('bonsai importedmodel show --name "{}" -o json > status.json'.format(
        import_name,
    ))

    # Confirm model import succeeded
    with open('status.json') as fname:
        status = json.load(fname)

    assert status['Status'] == 'Succeeded'

# Use CLI to create, upload inkling, train, and wait til complete
def test_train_brain(brain_name, brain_version, inkling_fname, simulator_package_name):
    os.system('bonsai brain create -n {}'.format(
        brain_name,
    ))
    os.system('bonsai brain version update-inkling -n {} --version {} -f {}'.format(
        brain_name,
        brain_version,
        inkling_fname
    ))
    concept_names = ['ImportedConcept', 'MoveToCenter']
    for concept in concept_names:
        time.sleep(20)
        if concept == 'ImportedConcept':
            os.system('bonsai brain version start-training -n {} --version {} -c {}'.format(
                brain_name,
                brain_version,
                concept
            ))
        else:
            os.system('bonsai brain version start-training -n {} --version {} --simulator-package-name {} -c {}'.format(
                brain_name,
                brain_version,
                simulator_package_name,
                concept
            ))
        
        # Do not continue until training is complete
        running = True
        while running:
            time.sleep(20)
            os.system('bonsai brain version show --name {} --version {} -o json > status.json'.format(
                brain_name,
                brain_version,
            ))
            with open('status.json') as fname:
                status = json.load(fname)
            if status['trainingState'] == 'Active':
                pass
            else:
                running = False
                time.sleep(300)
                print('Training complete...')

        # Final check concepts are complete
        with open('status.json') as fname:
            status = json.load(fname)
        assert status['status'] == 'Succeeded'
    print('All Concepts trained')

# Main test function for
# 1. running custom assessment using bonsai-cli
# 2. retrieving data from Log Analytics Workspace using LogAnalyticsDataClient
# 3. flattening states, actions, and configs
# 4. making plots for episode metrics
# 5. qualifying pass/fail
def test_assessment_brain(brain_name, brain_version, concept_name, file_name, simulator_package_name, instance_count, custom_assess_name, log_analy_workspace):
    # Run custom assessment
    os.system('bonsai brain version assessment start --brain-name {} --brain-version {} --concept-name {} --file {} --simulator-package-name {} --instance-count {} --name {}'.format(
        brain_name,
        brain_version,
        concept_name,
        file_name,
        simulator_package_name,
        instance_count,
        custom_assess_name,
        custom_assess_name
    ))

    # Do not continue until assessment is complete and waited 5 minutes
    running = True
    while running:
        time.sleep(10)
        os.system('bonsai brain version assessment show --brain-name {} --brain-version {} --name {} -o json > status.json'.format(
            brain_name,
            brain_version,
            custom_assess_name
        ))
        with open('status.json') as fname:
            status = json.load(fname)
        if status['status'] == 'Completed':
            running = False
            print('Assessment complete, waiting 5 min for data to appear in LAW...')
            for i in range(5):
                print('{} min...'.format(5-i))
                time.sleep(60)
    
    # Extract telescope from LAW using workspace ID and return flattened
    df = extract_telescope(log_analy_workspace, brain_name, brain_version, custom_assess_name)
    
    # Make plots
    # EpisodeIndex based on unique EpisodeIds
    df['EpisodeIndex'] = np.zeros(len(df))
    k = 1
    for i in list(set(df['EpisodeId'])):
        for j in range(len(df)):
            if df['EpisodeId'].iloc[j] == i:
                df.at[j,'EpisodeIndex'] = k
        k += 1

    # manipulate
    df['distance_to_center'] = np.sqrt(df['ball_x'] ** 2 + df['ball_y'] ** 2)
    df['velocity_magnitude'] = np.sqrt(df['ball_vel_x'] ** 2 + df['ball_vel_y'] ** 2)

    # Create dataframe consisting of episode finish metrics
    df_last = pd.DataFrame({})
    mse_dist_list = []
    mse_vel_list = []
    for ep in range(1, int(df['EpisodeIndex'].max())+1):
        last_iter = df[(df['EpisodeIndex']==ep) & (df['IterationIndex']==len(df[df['EpisodeIndex']==ep]))]
        
        mse_dist_list.append(np.square(np.subtract(0, df[(df['EpisodeIndex']==ep)]['distance_to_center'])).mean())
        mse_vel_list.append(np.square(np.subtract(0, df[(df['EpisodeIndex']==ep)]['velocity_magnitude'])).mean())
        
        df_last = pd.concat([df_last, last_iter], sort=False)
    
    df_last['mse_dist'] = mse_dist_list
    df_last['mse_vel'] = mse_vel_list

    # Create dataframe consisting of summary info
    df_summary = {}
    df_summary['percentage_full_episodes'] = (len(df[df['IterationIndex']==251]) / df['EpisodeIndex'].max()) * 100
    df_summary['avg_final_distance_to_center'] = np.mean(df_last['distance_to_center'])
    df_summary['avg_final_velocity_magnitude'] = np.mean(df_last['velocity_magnitude'])
    df_summary['mse_dist_total'] = np.square(np.subtract(0, df['distance_to_center'])).mean()
    df_summary['mse_vel_total'] = np.square(np.subtract(0, df['velocity_magnitude'])).mean()
    
    # Save Summary values as json
    with open('brain_summary.json', 'w') as outfile:
        json.dump(df_summary, outfile)

    # Plot Final Values
    fig, ax = plt.subplots(1, 1, figsize=(16, 8))
    episodes = range(1, int(df['EpisodeIndex'].max()+1))
    ax.plot(episodes, df_last['distance_to_center']) 
    ax.plot(episodes, df_last['velocity_magnitude']) 
    ax.legend(['Final Distance to Center', 'Final Velocity Mag'])
    ax.set_xlabel('Custom Assessment Episodes')
    fig.suptitle('brain \n Percentage of Full Episodes: {:0.2f}% \n Average Final Ball Distance To Center: {:0.4f} \n Average Final Ball Velocity Mag: {:0.4f} \n'.format(df_summary['percentage_full_episodes'], df_summary['avg_final_distance_to_center'], df_summary['avg_final_velocity_magnitude']), fontsize=14)

    # Plot MSE Values
    figa, axa = plt.subplots(1, 1, figsize=(16, 8))
    axa.plot(episodes, df_last['mse_dist']) 
    axa.plot(episodes, df_last['mse_vel']) 
    axa.legend(['MSE Distance', 'MSE Vel Mag'])
    axa.set_xlabel('Custom Assessment Episodes')
    figa.suptitle('brain \n Percentage of Full Episodes: {:0.2f}% \n Average MSE Ball Distance To Center: {:0.4f} \n Average MSE Ball Velocity Mag: {:0.4f} \n'.format(df_summary['percentage_full_episodes'], df_summary['mse_dist_total'], df_summary['mse_vel_total']), fontsize=14)


    print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
    for key, val in df_summary.items():
        print(key, val)
    print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
    #plt.show()
    
    # Assert tests for qualification
    assert df_summary['percentage_full_episodes'] >= 50
    assert df_summary['avg_final_distance_to_center'] <= 0.02
    assert df_summary['avg_final_velocity_magnitude'] <= 0.012
    assert df_summary['mse_dist_total'] <= 0.004
    assert df_summary['mse_vel_total'] <= 0.004

# Extract telescope data using query
@pytest.mark.skip(reason="helper")
def extract_telescope(log_analy_workspace_id, brain_name, brain_version, assessment_name):
    creds, _ = get_azure_cli_credentials(resource="https://api.loganalytics.io")
    log_client = LogAnalyticsDataClient(creds)
    myWorkSpaceId = log_analy_workspace_id
    result = log_client.query(myWorkSpaceId, QueryBody(**{
        'query': (
            'EpisodeLog_CL'
            '| where BrainName_s == "{}" and BrainVersion_d == "{}" and AssessmentName_s == "{}"'
            '| where  TimeGenerated > ago(30d)'
            '| join kind=inner ('
            'IterationLog_CL'
            '| sort by Timestamp_t desc'
            ') on EpisodeId_g'
            '| project AssessmentName = AssessmentName_s, EpisodeId = EpisodeId_g, IterationIndex = IterationIndex_d, Timestamp = Timestamp_t, SimState = parse_json(SimState_s), SimAction = parse_json(SimAction_s), Reward = Reward_d, CumulativeReward = CumulativeReward_d, Terminal = Terminal_b, LessonIndex = LessonIndex_d, SimConfig = parse_json(SimConfig_s), GoalMetrics = parse_json(GoalMetrics_s), EpisodeType = EpisodeType_s, FinishReason = FinishReason_s'
            '| order by EpisodeId asc, IterationIndex asc'
        ).format(brain_name, str(brain_version), assessment_name)
    }))

    df = pd.DataFrame(result.tables[0].rows, columns=[result.tables[0].columns[i].name for i in range(len(result.tables[0].columns))])

    df_flattened = format_kql_logs(df)
    df_flattened.to_csv('flattened_telescope.csv')
    return df_flattened

# Flatten data
@pytest.mark.skip(reason="helper")
def format_kql_logs(df: pd.DataFrame) -> pd.DataFrame:
    ''' Function to format a dataframe obtained from KQL query.
        Output format: keeps only selected columns, and flatten nested columns [SimAction, SimState, SimConfig]
        Parameters
        ----------
        df : DataFrame
            dataframe obtained from running KQL query then exporting `_kql_raw_result_.to_dataframe()`
    '''
    selected_columns = ["Timestamp", "IterationIndex", "Reward", "CumulativeReward", "Terminal", "SimState", "SimAction", "SimConfig", "EpisodeId"]
    nested_columns =  ["SimState", "SimAction", "SimConfig"]
    df_selected_columns = df[selected_columns]
    series_lst = []
    ordered_columns = ["EpisodeId", "IterationIndex", "Reward", "Terminal"]
    for i in nested_columns:
        try:
            new_series = df_selected_columns[i].apply(ast.literal_eval).apply(pd.Series)
        except:
            df_selected_columns[i].fillna(value=str({key: str(np.nan) for key, value in ast.literal_eval(df_selected_columns[i][1]).items()}), inplace=True)
            new_series = df_selected_columns[i].apply(ast.literal_eval).apply(pd.Series)
        column_names = new_series.columns.values.tolist()
        series_lst.append(new_series)
        if len(column_names) > 0:
            ordered_columns.extend(column_names)
        del(df_selected_columns[i])

    series_lst.append(df_selected_columns)
    formated_df = pd.concat(series_lst, axis=1)
    formated_df = formated_df.sort_values(by='Timestamp',ascending=True) # reorder df based on Timestamp
    formated_df.index = range(len(formated_df)) # re-index
    formated_df['Timestamp']=pd.to_datetime(formated_df['Timestamp']) # convert Timestamp to datetime

    formated_df = formated_df[ordered_columns]
    return formated_df.sort_values(by=["EpisodeId", "IterationIndex"])