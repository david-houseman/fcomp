import flask
import dash
import dash_bootstrap_components as dbc
import dash_core_components as dcc
import dash_html_components as html
import dash_table as dtab
from dash.dependencies import Input, Output, State

import json
import math
import pandas as pd
import numpy as np
import psycopg2
import fcntl

# import plotly.graph_objs as go

from datetime import datetime, timedelta, date, time
import re
import os

server = flask.Flask(__name__)
app = dash.Dash(
    name=__name__, server=server, external_stylesheets=[dbc.themes.BOOTSTRAP]
)


def read_config(config_path):
    with open(config_path) as f:
        config = json.load(f)

    comp_start = datetime.strptime(config["competition_start"], "%Y-%m-%d")
    comp_end = datetime.strptime(config["competition_end"], "%Y-%m-%d")
    assert comp_start.weekday() == comp_end.weekday()
    assert comp_start <= comp_end

    sub_start = datetime.strptime(config["submission_start"], "%H:%M:%S").time()
    sub_end = datetime.strptime(config["submission_end"], "%H:%M:%S").time()
    assert sub_start <= sub_end

    return comp_start, comp_end, sub_start, sub_end


# Set some globals. Todo: not sure how else to pass these into the callbacks.
comp_start, comp_end, sub_start, sub_end = read_config("../config/config.json")

submissions_file = "../data/submissions.csv"


def competition_days():
    t = comp_start
    while t <= comp_end:
        yield t
        t += timedelta(days=7)


def component_title():
    return html.Div(
        html.H2("USyd QBUS3850 Forecast Competition"), style={"padding": 50}
    )


def component_submission_form():
    maxlen = 256
    horizon_start = (comp_start + timedelta(days=1)).strftime("%a")
    horizon_end = comp_start.strftime("%a")

    return html.Div(
        [
            html.P(
                "Submission times: each {}, {} to {}.".format(
                    comp_start.strftime("%a"), sub_start, sub_end
                )
            ),
            dbc.FormGroup(
                [
                    dbc.Label("Name", html_for="input-name"),
                    dbc.Input(
                        id="input-name", placeholder="Enter name", maxLength=maxlen
                    ),
                    dbc.FormText("Allowed characters: A-Za-z',-.<space>"),
                ]
            ),
            dbc.FormGroup(
                [
                    dbc.Label("Student No", html_for="input-snumber"),
                    dbc.Input(
                        id="input-snumber",
                        placeholder="Enter student no",
                        maxLength=maxlen,
                    ),
                    dbc.FormText("Nine numeric digits, no spaces"),
                ]
            ),
            dbc.FormGroup(
                [
                    dbc.Label(
                        "Forecasts for {} - {}".format(horizon_start, horizon_end),
                        html_for="input-forecasts",
                    ),
                    dbc.Input(
                        id="input-forecasts",
                        placeholder="Enter forecasts",
                        maxLength=maxlen,
                    ),
                    dbc.FormText("Seven floating point numbers, comma-separated"),
                ]
            ),
            dbc.Button("Submit", id="submit-button"),
            dbc.Jumbotron([html.Div(id="submit-feedback")]),
        ]
    )


def component_weekly_results():
    read_cols = (
        ["forecast_date", "participant", "fullname", "origin"]
        + ["h{}".format(h + 1) for h in range(7)]
        + ["rmsfe"]
    )
    select_cols = (
        ["forecast_datestr", "participant", "fullname", "origin"]
        + ["h{}".format(h + 1) for h in range(7)]
        + ["rmsfe"]
    )
    title_cols = (
        ["forecast_date", "participant", "fullname", "origin"]
        + [(comp_start + timedelta(days=h + 1)).strftime("%a") for h in range(7)]
        + ["rmsfe"]
    )

    connection = psycopg2.connect(user="root", database="root")
    now = datetime.now()
    content = []
    for t in competition_days():
        week_df = pd.read_sql(
            "SELECT * FROM week_errors_view WHERE forecast_date = %s;",
            params=[t],
            con=connection,
            parse_dates=["forecast_date"],
            columns=read_cols,
        )

        if week_df.empty:
            continue

        if now < t + timedelta(days=1):
            continue

        week_df["forecast_datestr"] = week_df["forecast_date"].map(
            lambda t: t.strftime("%Y-%m-%d")
        )

        content.append(
            dtab.DataTable(
                data=week_df.to_dict("records"),
                columns=[{"name": i, "id": j} for i, j in zip(title_cols, select_cols)],
            )
        )
        content.append(html.P(t.strftime("%Y-%m-%d")))

    connection.close()

    content.reverse()

    header = [
        html.H4("Weekly results"),
        html.P(
            "Origin column abbreviations: 'A' = Auto, 'B' = Benchmark, 'M' = Manual."
        ),
    ]

    return html.Div(header + content)


def component_git_version():
    git_shorthash = "Unknown"
    git_time = "00:00"
    git_author = "Unknown"

    git_output = (
        os.popen("git show --no-patch --format='%h%n%ai%n%an'").read().splitlines()
    )

    if len(git_output) == 3:
        git_shorthash = git_output[0]
        git_time = git_output[1]
        git_author = git_output[2]

    return html.P(
        "Version {} [{}] by {}".format(git_shorthash, git_time, git_author),
        style={"color": "grey", "font-size": "small"},
    )


def app_layout():
    content = [
        component_title(),
        html.Hr(),
        component_submission_form(),
        html.Hr(),
        component_weekly_results(),
        html.Hr(),
        component_git_version(),
    ]
    return html.Div(dbc.Container([dbc.Row([dbc.Col(content)])]))


def enabled_tuple(msg):
    return False, False, False, False, msg


def suspended_tuple(msg):
    return True, True, True, True, msg


@app.callback(
    [
        Output("input-name", "disabled"),
        Output("input-snumber", "disabled"),
        Output("input-forecasts", "disabled"),
        Output("submit-button", "disabled"),
        Output("submit-feedback", "children"),
    ],
    [Input("submit-button", "n_clicks")],
    [
        State("input-name", "value"),
        State("input-snumber", "value"),
        State("input-forecasts", "value"),
    ],
)
def update_form(n_clicks, name, snumber, fcasts_str):

    now = datetime.now()

    if (
        now.weekday() != comp_start.weekday()
        or now.time() < sub_start
        or now.time() > sub_end
    ):
        now_str = now.strftime(format="%a %Y-%m-%d %H:%M:%S")
        msg = [
            html.P("Submissions are not accepted now."),
            html.P(
                "Submission times: each {}, {} to {}.".format(
                    comp_start.strftime("%a"), sub_start, sub_end
                )
            ),
            html.P("Current time is {}.".format(now_str)),
        ]
        return suspended_tuple(msg)

    if not n_clicks:
        msg = "Submissions are accepted today until {}.".format(sub_end)
        return enabled_tuple(msg)

    if not name:
        msg = "Required: Name"
        return enabled_tuple(msg)

    if not snumber:
        msg = "Required: Student No"
        return enabled_tuple(msg)

    if not fcasts_str:
        msg = "Required: Forecasts"
        return enabled_tuple(msg)

    if not re.match("[-,.\ 'A-Za-z]+$", name):
        msg = "Allowed characters for name: A-Za-z',-.<space>."
        return enabled_tuple(msg)

    if not re.match("[0-9]{9}$", snumber):
        msg = "Student No must be 9 digits, with no spaces."
        return enabled_tuple(msg)

    fstrs = fcasts_str.split(",")
    nf = len(fstrs)
    if nf < 7:
        msg = "Too few forecasts: Expected 7, received {}.".format(nf)
        return enabled_tuple(msg)
    if nf > 7:
        msg = "Too many forecasts: Expected 7, received {}.".format(nf)
        return enabled_tuple(msg)

    try:
        fcasts = [float(s) for s in fstrs]
    except ValueError:
        msg = "Failed to parse forecast {} as float.".format(s)
        return enabled_tuple(msg)

    date_str = now.strftime(format="%Y-%m-%d")
    time_str = now.strftime(format="%H:%M:%S")
    origin = "M"

    # Write to the database.
    connection = psycopg2.connect(user="root", database="root")
    cursor = connection.cursor()
    cursor.execute(
        """
INSERT INTO submissions 
VALUES( %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s );
""",
        (date_str, time_str, snumber, name, origin, *fcasts),
    )
    cursor.execute("CALL main(%s, %s);", (comp_start.date(), comp_end.date()))
    connection.commit()
    connection.close()

    # Write to the backup file.
    record = [date_str, time_str, snumber, name, origin] + [str(f) for f in fcasts]
    with open(submissions_file, "a+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write("|".join(record) + "\n")
        fcntl.flock(f, fcntl.LOCK_UN)

    # Write back to the app.
    msg = [
        html.P("Thank you for submitting your forecasts:"),
        html.P(" | ".join(record)),
    ]
    return suspended_tuple(msg)


app.layout = app_layout

if __name__ == "__main__":
    app.run_server(debug=True)
