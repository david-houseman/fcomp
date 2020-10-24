import dash
import dash_bootstrap_components as dbc
import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output, State


#import numpy as np
#import pandas as pd
#import plotly.graph_objs as go

from datetime import datetime, timedelta 
import re
import os

submission_day = "Sat"

app = dash.Dash(
    name=__name__,
#    suppress_callback_exceptions = True,
    external_stylesheets=[dbc.themes.BOOTSTRAP]
)

form_max_length = 256

content = [
    html.Div(
        html.H2("USyd QBUS3850 Forecast Competition"),
        style={'padding': 50},
    ),
    html.P(
        "Submission times: each {}, 00:00:00 to 23:59:59.".format(
            submission_day,
        )
    ),
    dbc.FormGroup(
        [
            dbc.Label("Name", html_for="input-name"),
            dbc.Input(
                id="input-name",
                placeholder="Enter name",
                maxLength=form_max_length,
            ),
            dbc.FormText("Allowed characters: A-Za-z',-<space>"),
        ]
    ),
    dbc.FormGroup(
        [
            dbc.Label("Student No", html_for="input-snumber"),
            dbc.Input(
                id="input-snumber",
                placeholder="Enter student no",
                maxLength=form_max_length,
            ),
            dbc.FormText("Nine numeric digits, no spaces"),
        ]
    ),
    dbc.FormGroup(
        [
            dbc.Label("Forecasts", html_for="input-forecasts"),
            dbc.Input(
                id="input-forecasts",
                placeholder="Enter forecasts",
                maxLength=form_max_length,
            ),
            dbc.FormText("Seven floating point numbers, comma-separated"),
        ]
    ),
    dbc.Button(
        "Submit",
        id="submit-button"
    ),
    dbc.Jumbotron(
        [
            html.Div(
                id="submit-feedback",
            )
        ]
    )
]


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
    [
        Input("submit-button", "n_clicks"),
    ],
    [
        State("input-name", "value"),
        State("input-snumber", "value"),
        State("input-forecasts", "value"),
    ]
)
def update_form(n_clicks, name, snumber, forecasts):

    now = datetime.now()

    if not now.strftime("%a") == submission_day:
        now_str = now.strftime(format="%a %Y-%m-%d %H:%M:%S")
        msg = [
            html.P("Submissions are not accepted now."),
            html.P(
                "Submission times: each {}, 00:00:00 to 23:59:59.".format(
                    submission_day,
                )
            ),
            html.P("Current time is {}.".format(now_str)),
        ]
        return suspended_tuple(msg)
   
    if not n_clicks:
        msg = "Submissions are accepted today until 23:59:59."
        return enabled_tuple(msg)
    
    if not name:
        msg = "Required: Name"
        return enabled_tuple(msg)
        
    if not snumber:
        msg = "Required: Student No"
        return enabled_tuple(msg)

    if not forecasts:
        msg = "Required: Forecasts"
        return enabled_tuple(msg)

    if not re.match("[-,\ \'A-Za-z]+$", name):
        msg = "Allowed characters for name: A-Za-z',-<space>."
        return enabled_tuple(msg)
    
    if not re.match("[0-9]{9}$", snumber):
        msg = "Student No must be 9 digits, with no spaces."
        return enabled_tuple(msg)
        
    fstrs = forecasts.split(",")
    nf = len(fstrs)
    if nf < 7:
        msg = "Too few forecasts: Expected 7, received {}.".format(nf)
        return enabled_tuple(msg)
    if nf > 7:
        msg = "Too many forecasts: Expected 7, received {}.".format(nf)
        return enabled_tuple(msg)

    fcasts = []
    for s in fstrs:
        try:
            fcasts.append(float(s))
        except ValueError:
            msg = "Failed to parse forecast {} as float.".format(s)
            return enabled_tuple(msg)

    date_str = now.strftime(format="%Y-%m-%d")
    time_str = now.strftime(format="%H:%M:%S")
    method = "M"
    record = [date_str, time_str, snumber, name, method] + [str(f) for f in fcasts]
    
    msg = [
        html.P("Thank you for submitting your forecasts:"),
        html.P(" | ".join(record)),
    ]

    f = open("../data/submissions.csv", "a")
    f.write("|".join(record) + "\n")
    f.close()
    
    return suspended_tuple(msg)
    

app.layout = html.Div(
    dbc.Container(
        [
            dbc.Row(
                [
                    dbc.Col(
                        content
                    )
                ]
            )       
        ]
    ),
)
        
if __name__ == "__main__":
    app.run_server(debug=True)
