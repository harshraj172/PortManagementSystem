from django.shortcuts import render
from django.db import connection, transaction, IntegrityError
from django.http import HttpResponse

# 1) Search for ships
def search_ships(request):
    origin_port = request.GET.get('origin_port', '')
    destination_port = request.GET.get('destination_port', '')

    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT s.ShipID, s.Name, sr.CostPerKG, sr.Duration,
                   p1.PortName AS Origin, p2.PortName AS Destination
              FROM Ship s
              JOIN ShipRoute sr ON s.ShipID = sr.ShipID
              JOIN Route r ON sr.RouteID = r.RouteID
              JOIN Port p1 ON r.OriginPortID = p1.PortID
              JOIN Port p2 ON r.DestinationPortID = p2.PortID
             WHERE p1.PortName = %s
               AND p2.PortName = %s
        """, [origin_port, destination_port])
        results = dictfetchall(cursor)

    return render(request, 'search_results.html', {'routes': results})

def dictfetchall(cursor):
    """Return all rows from a cursor as a list of dicts."""
    columns = [col[0] for col in cursor.description]
    return [
        dict(zip(columns, row))
        for row in cursor.fetchall()
    ]


# 2) Book an order
def book_order(request):
    if request.method == 'POST':
        try:
            weight = float(request.POST.get('weight', '0'))
            customer_id = request.POST.get('customer_id')  # or from request.user, if using Django's auth
            shiproute_id = request.POST.get('shiproute_id')
            description = request.POST.get('description', 'Customer Cargo')

            with transaction.atomic():
                # 1) Insert cargo
                with connection.cursor() as cursor:
                    cargo_sql = """
                        INSERT INTO Cargo
                            (Description, Weight, Type, OriginPortID, DestinationPortID, Status)
                        VALUES (%s, %s, 'Container', 1, 2, 'AtOrigin')
                    """
                    cursor.execute(cargo_sql, [description, weight])
                    cargo_id = cursor.lastrowid

                # 2) Insert order (the DB trigger calculates price & profit)
                with connection.cursor() as cursor:
                    order_sql = """
                        INSERT INTO Orders (CustomerID, ShipRouteID, CargoID)
                        VALUES (%s, %s, %s)
                    """
                    cursor.execute(order_sql, [customer_id, shiproute_id, cargo_id])

            return HttpResponse("Order Booked Successfully!")
        except IntegrityError:
            return HttpResponse("Error booking order!", status=400)

    # GET request: show a simple booking form
    return render(request, 'book_order.html')


# 3) Admin Markup (calls stored procedure: UpdateAdminPrice)
def admin_markup(request):
    if request.method == 'POST':
        shiproute_id = request.POST.get('shiproute_id')
        markup_percentage = request.POST.get('markup_percentage')
        with connection.cursor() as cursor:
            cursor.callproc('UpdateAdminPrice', [shiproute_id, markup_percentage])
        return HttpResponse("Markup updated successfully.")
    return render(request, 'admin_markup_form.html')


# 4) Daily Profit Chart
def daily_profit_chart(request):
    # Example of how to query your DailyFinancials table
    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT FinancialDate, TotalProfit
              FROM DailyFinancials
             ORDER BY FinancialDate
        """)
        rows = cursor.fetchall()
    # Convert to chart-friendly data
    labels = [str(r[0]) for r in rows]   # e.g. ["2025-01-01","2025-01-02"]
    data = [float(r[1]) for r in rows]   # [100.0, 200.5, ...]

    return render(request, 'profit_chart.html', {'labels': labels, 'data': data})
