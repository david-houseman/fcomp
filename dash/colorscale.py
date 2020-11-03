import dash_html_components as html
import colorlover
import math

# From https://dash.plotly.com/datatable/conditional-formatting


def colorscale_fill(df, n_bins=11, columns="all"):
    bounds = [i * (1.0 / n_bins) for i in range(n_bins + 1)]
    if columns == "all":
        if "id" in df:
            df_numeric_columns = df.select_dtypes("number").drop(["id"], axis=1)
        else:
            df_numeric_columns = df.select_dtypes("number")
    else:
        df_numeric_columns = df[columns]
    df_max = df_numeric_columns.max().max()
    df_min = df_numeric_columns.min().min()
    ranges = [((df_max - df_min) * i) + df_min for i in bounds]
    styles = []
    for i in range(1, len(bounds)):
        min_bound = ranges[i - 1]
        max_bound = ranges[i]
        backgroundColor = colorlover.scales[str(n_bins)]["div"]["RdYlBu"][i - 1]
        color = "white" if i > len(bounds) / 2.0 else "inherit"

        for column in df_numeric_columns:
            styles.append(
                {
                    "if": {
                        "filter_query": (
                            "{{{column}}} >= {min_bound}"
                            + (
                                " && {{{column}}} < {max_bound}"
                                if (i < len(bounds) - 1)
                                else ""
                            )
                        ).format(
                            column=column, min_bound=min_bound, max_bound=max_bound
                        ),
                        "column_id": column,
                    },
                    "backgroundColor": backgroundColor,
                    "color": color,
                }
            )

    return styles


def colorbar_fill(df, column, color="#408040", min_val=None, max_val=None):
    if min_val is None:
        min_val = df[column].min()

    if max_val is None:
        max_val = df[column].max()

    n_bins = 100
    styles = []
    delta = (max_val - min_val) / n_bins

    # Do nothing if max_val or min_val is nan or +/- inf.
    if delta * 0.0 != 0.0:
        return styles

    for i in range(n_bins):
        fractional_fill = i * 100.0 / n_bins

        lhs = min_val + i * delta
        rhs = lhs + delta

        filter_lhs = "{{{column}}} >= {lhs}".format(column=column, lhs=lhs)
        filter_rhs = "{{{column}}} < {rhs}".format(column=column, rhs=rhs)

        filter_query = (
            filter_rhs
            if i == 0
            else filter_lhs + " && " + filter_rhs
            if i < n_bins - 1
            else filter_lhs
        )

        styles.append(
            {
                "if": {"filter_query": filter_query, "column_id": column},
                "background": (
                    """
                    linear-gradient(90deg,
                    {color} 0%,
                    {color} {fractional_fill}%,
                    white {fractional_fill}%,
                    white 100%)
                """.format(
                        color=color, fractional_fill=fractional_fill
                    )
                ),
                "paddingBottom": 2,
                "paddingTop": 2,
            }
        )

    return styles
