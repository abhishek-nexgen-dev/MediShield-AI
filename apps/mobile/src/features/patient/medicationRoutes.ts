export function hospitalMedicationsHref(hospitalId: string) {
  return { pathname: '/patient/medications/[hospitalId]', params: { hospitalId } } as const;
}

export function medicationDetailHref(hospitalId: string, medicationId: string) {
  return { pathname: '/patient/medications/[hospitalId]/[medicationId]', params: { hospitalId, medicationId } } as const;
}
