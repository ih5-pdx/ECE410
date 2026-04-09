from graphviz import Digraph


def create_system_diagram(output_name="system_diagram"):
    """
    Generate a system diagram PNG for a matrix multiplication chiplet project.
    Output file: system_diagram.png
    """

    dot = Digraph("System_Diagram", format="png")
    dot.attr(rankdir="LR")
    dot.attr(
        label="System Diagram for Matrix Multiplication Chiplet",
        labelloc="t",
        fontsize="20"
    )

    # External blocks
    dot.node("CPU", "Host CPU", shape="box", style="filled", fillcolor="lightblue")
    dot.node("BUS", "AXI-Lite Interface", shape="box", style="filled", fillcolor="lightgray")
    dot.node("OUT", "Output Matrix", shape="box", style="filled", fillcolor="plum")

    # Chiplet internals
    with dot.subgraph(name="cluster_chiplet") as c:
        c.attr(label="Matrix Multiplication Chiplet", color="darkgreen", style="rounded")
        c.node("CTRL", "Control Registers", shape="box", style="filled", fillcolor="lightyellow")
        c.node("INA", "Input Buffer A", shape="box", style="filled", fillcolor="palegreen")
        c.node("INB", "Input Buffer B", shape="box", style="filled", fillcolor="palegreen")
        c.node("MAC", "MAC Array /\\nMultiply Core", shape="box", style="filled", fillcolor="moccasin")
        c.node("ACC", "Accumulator", shape="box", style="filled", fillcolor="moccasin")
        c.node("BUF", "Output Buffer", shape="box", style="filled", fillcolor="lightpink")

        c.edge("CTRL", "INA")
        c.edge("CTRL", "INB")
        c.edge("INA", "MAC")
        c.edge("INB", "MAC")
        c.edge("MAC", "ACC")
        c.edge("ACC", "BUF")

    # External connections
    dot.edge("CPU", "BUS")
    dot.edge("BUS", "CTRL")
    dot.edge("BUF", "OUT")

    output_path = dot.render(output_name, cleanup=True)
    print(f"Generated: {output_path}")


if __name__ == "__main__":
    create_system_diagram()
