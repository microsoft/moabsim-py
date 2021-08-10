# Helper function for arguments for pytest, with defaults
def pytest_addoption(parser):
    parser.addoption("--brain_name", action="store", default="my_brain")
    parser.addoption("--brain_version", action="store", default=1)
    parser.addoption("--concept_name", action="store", default="MoveToCenter")
    parser.addoption("--file_name", action="store", default="assess_config.json")
    parser.addoption("--simulator_package_name", action="store", default="Moab")
    parser.addoption("--instance_count", action="store", default="20")
    parser.addoption("--custom_assess_name", action="store", default="my_custom_assessment")
    parser.addoption("--log_analy_workspace", action="store", default=None)
    parser.addoption("--inkling_fname", action="store", default="./Machine-Teaching-Examples/model_import/moab-imported-concept.ink")
    parser.addoption("--import_name", action="store", default="My ML Model")
    parser.addoption("--model_file_path", action="store", default="./Machine-Teaching-Examples/model_import/state_transform_deep.zip")