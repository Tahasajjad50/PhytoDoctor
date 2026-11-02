import math
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.deps import get_current_user, require_admin
from app.models.customer import Customer
from app.models.user import User, UserRole
from app.schemas.customer import CustomerCreate, CustomerResponse

router = APIRouter(prefix="/customers", tags=["Customer & Territory Management"])

def _distance_sq(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    return (lat1 - lat2) ** 2 + (lon1 - lon2) ** 2

@router.post("/", response_model=CustomerResponse, status_code=status.HTTP_201_CREATED)
async def create_customer(
    data: CustomerCreate,
    current_user: User = Depends(require_admin), # CEO and Admins (Managers) ONLY
    db: AsyncSession = Depends(get_db)
):
    """
    Register a customer (Farm, Dealer, Retailer).
    Authorized for Admin and CEO ONLY.
    If assigned_employee_id is not provided, automatically assigns to the nearest active field employee.
    """
    assigned_emp_id = data.assigned_employee_id
    assigned_emp_name: Optional[str] = None

    if assigned_emp_id:
        emp_res = await db.execute(select(User).where(User.id == assigned_emp_id))
        emp = emp_res.scalar_one_or_none()
        if emp:
            assigned_emp_name = emp.full_name
        else:
            assigned_emp_id = None

    # If no employee manually chosen, find the nearest field employee or territory match
    if not assigned_emp_id:
        emp_query = select(User).where(
            User.role == UserRole.EMPLOYEE.value,
            User.is_active == True,
        )
        # If manager is adding, prioritize employees under this manager
        if current_user.role == UserRole.MANAGER.value:
            emp_query = emp_query.where(User.manager_id == current_user.id)
            
        emp_res = await db.execute(emp_query)
        employees = emp_res.scalars().all()
        
        if not employees and current_user.role == UserRole.MANAGER.value:
            # Fallback to any active employee if manager's team is not yet populated
            all_emp_res = await db.execute(select(User).where(User.role == UserRole.EMPLOYEE.value, User.is_active == True))
            employees = all_emp_res.scalars().all()

        if employees:
            # Pick first employee or match by territory in designation/name if any
            matched = None
            for e in employees:
                if data.territory.lower() in (e.designation or "").lower() or data.territory.lower() in e.full_name.lower():
                    matched = e
                    break
            if not matched:
                matched = employees[0]
            assigned_emp_id = matched.id
            assigned_emp_name = matched.full_name

    new_cust = Customer(
        name=data.name.strip(),
        phone=data.phone.strip() if data.phone else None,
        customer_type=data.customer_type.upper(),
        territory=data.territory.strip(),
        address=data.address.strip() if data.address else None,
        crop_focus=data.crop_focus.strip() if data.crop_focus else None,
        latitude=data.latitude,
        longitude=data.longitude,
        assigned_employee_id=assigned_emp_id,
        created_by_id=current_user.id,
    )
    db.add(new_cust)
    await db.commit()
    await db.refresh(new_cust)

    resp = CustomerResponse.model_validate(new_cust)
    resp.assigned_employee_name = assigned_emp_name
    return resp


@router.get("/", response_model=List[CustomerResponse])
async def list_customers(
    territory: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List customers.
    - CEO & Admins: See all customers across territories.
    - Employees: See customers in their territory or assigned to them.
    """
    query = select(Customer)
    if current_user.role == UserRole.EMPLOYEE.value:
        query = query.where(
            or_(
                Customer.assigned_employee_id == current_user.id,
                Customer.territory.ilike(f"%{current_user.full_name}%"),
            )
        )
    if territory:
        query = query.where(Customer.territory.ilike(f"%{territory}%"))

    query = query.order_by(Customer.created_at.desc())
    res = await db.execute(query)
    customers = res.scalars().all()

    results: List[CustomerResponse] = []
    for c in customers:
        emp_name = None
        if c.assigned_employee_id:
            emp_res = await db.execute(select(User.full_name).where(User.id == c.assigned_employee_id))
            emp_name = emp_res.scalar_one_or_none()
        r = CustomerResponse.model_validate(c)
        r.assigned_employee_name = emp_name
        results.append(r)

    return results
